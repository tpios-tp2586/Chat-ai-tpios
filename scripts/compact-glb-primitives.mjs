import fs from 'node:fs';

const input = process.argv[2];
const output = process.argv[3] || input;
if (!input) throw new Error('Usage: node compact-glb-primitives.mjs input.glb [output.glb]');
const file = fs.readFileSync(input);
if (file.toString('ascii', 0, 4) !== 'glTF' || file.readUInt32LE(4) !== 2 || file.readUInt32LE(8) !== file.length) throw new Error('Invalid GLB 2.0');
let offset = 12, json, bin;
while (offset < file.length) {
  const size = file.readUInt32LE(offset), type = file.readUInt32LE(offset + 4); offset += 8;
  const chunk = file.subarray(offset, offset + size); offset += size;
  if (type === 0x4e4f534a) json = JSON.parse(chunk.toString('utf8').trim());
  if (type === 0x004e4942) bin = Buffer.from(chunk);
}
if (!json || !bin || json.buffers?.length !== 1 || json.buffers[0].uri) throw new Error('Expected one embedded GLB buffer');

const sizeOf = { 5121: 1, 5123: 2, 5125: 4, 5126: 4 };
const read = {
  5121: (v, o) => v.getUint8(o), 5123: (v, o) => v.getUint16(o, true),
  5125: (v, o) => v.getUint32(o, true), 5126: (v, o) => v.getFloat32(o, true),
};
const write = {
  5121: (v, o, n) => v.setUint8(o, n), 5123: (v, o, n) => v.setUint16(o, n, true),
  5125: (v, o, n) => v.setUint32(o, n, true), 5126: (v, o, n) => v.setFloat32(o, n, true),
};
const countOf = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 };
const appended = [];
let appendedSize = 0;
function addView(data, target) {
  const pad = (4 - appendedSize % 4) % 4;
  if (pad) { appended.push(Buffer.alloc(pad)); appendedSize += pad; }
  const id = json.bufferViews.length;
  json.bufferViews.push({ buffer: 0, byteOffset: bin.length + appendedSize, byteLength: data.length, ...(target ? { target } : {}) });
  appended.push(data); appendedSize += data.length;
  return id;
}
function encode(values, componentType) {
  const size = sizeOf[componentType];
  if (!size) throw new Error('Unsupported component type ' + componentType);
  const data = Buffer.alloc(values.length * size);
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  values.forEach((value, i) => write[componentType](view, i * size, value));
  return data;
}
function readDense(id) {
  const a = json.accessors[id];
  if (!a) throw new Error('Missing accessor ' + id);
  const n = countOf[a.type], size = sizeOf[a.componentType];
  if (!n || !size || a.sparse || a.bufferView == null) throw new Error('Unsupported dense accessor ' + id);
  const bv = json.bufferViews[a.bufferView], stride = bv.byteStride || n * size;
  const start = (bv.byteOffset || 0) + (a.byteOffset || 0);
  const view = new DataView(bin.buffer, bin.byteOffset, bin.byteLength), out = [];
  for (let i = 0; i < a.count; i++) for (let c = 0; c < n; c++) out.push(read[a.componentType](view, start + i * stride + c * size));
  return { values: out, components: n };
}
function denseAccessor(values, old, target, bounds) {
  const view = addView(encode(values, old.componentType), target);
  const a = { bufferView: view, componentType: old.componentType, count: values.length / countOf[old.type], type: old.type };
  if (old.normalized) a.normalized = true;
  if (bounds) {
    const n = countOf[old.type]; a.min = Array(n).fill(Infinity); a.max = Array(n).fill(-Infinity);
    values.forEach((v, i) => { const c = i % n; a.min[c] = Math.min(a.min[c], v); a.max[c] = Math.max(a.max[c], v); });
  }
  json.accessors.push(a); return json.accessors.length - 1;
}
function sparseMorphAccessor(oldId, localMap, newCount) {
  const old = json.accessors[oldId], sp = old.sparse;
  if (!sp || old.bufferView != null || old.type !== 'VEC3' || old.componentType !== 5126) throw new Error('Unsupported morph accessor ' + oldId);
  const ibv = json.bufferViews[sp.indices.bufferView], vbv = json.bufferViews[sp.values.bufferView];
  const it = sp.indices.componentType, is = sizeOf[it];
  const iv = new DataView(bin.buffer, bin.byteOffset, bin.byteLength), vv = new DataView(bin.buffer, bin.byteOffset, bin.byteLength);
  const io = (ibv.byteOffset || 0) + (sp.indices.byteOffset || 0), vo = (vbv.byteOffset || 0) + (sp.values.byteOffset || 0);
  const ids = [], values = [];
  for (let i = 0; i < sp.count; i++) {
    const oldVertex = read[it](iv, io + i * is), local = localMap.get(oldVertex);
    if (local === undefined) continue;
    ids.push(local);
    for (let c = 0; c < 3; c++) values.push(vv.getFloat32(vo + (i * 3 + c) * 4, true));
  }
  const a = { componentType: 5126, count: newCount, type: 'VEC3' };
  if (ids.length) {
    const indexType = newCount <= 256 ? 5121 : newCount <= 65536 ? 5123 : 5125;
    a.sparse = { count: ids.length, indices: { bufferView: addView(encode(ids, indexType)), componentType: indexType }, values: { bufferView: addView(encode(values, 5126)) } };
    a.min = [Infinity, Infinity, Infinity]; a.max = [-Infinity, -Infinity, -Infinity];
    values.forEach((v, i) => { const c = i % 3; a.min[c] = Math.min(a.min[c], v); a.max[c] = Math.max(a.max[c], v); });
    if (ids.length < newCount) for (let c = 0; c < 3; c++) { a.min[c] = Math.min(a.min[c], 0); a.max[c] = Math.max(a.max[c], 0); }
  }
  json.accessors.push(a); return json.accessors.length - 1;
}

const meshes = json.meshes || [];
if (meshes.length !== 1) throw new Error('Expected one mesh, found ' + meshes.length);
const primitives = meshes[0].primitives || [];
if (primitives.length < 2) throw new Error('Expected multiple material primitives');
const base = primitives[0].attributes, keys = Object.keys(base).sort().join(','), morphCount = primitives[0].targets?.length || 0;
for (let i = 0; i < primitives.length; i++) {
  const p = primitives[i];
  if (Object.keys(p.attributes).sort().join(',') !== keys) throw new Error('Primitive ' + i + ' has different attributes');
  for (const key of Object.keys(base)) if (p.attributes[key] !== base[key]) throw new Error('Primitive ' + i + ' does not share ' + key + ' accessor');
  if ((p.targets?.length || 0) !== morphCount) throw new Error('Primitive ' + i + ' has different morph target count');
}
const vertexCount = readDense(base.POSITION).values.length / 3;
const usedVertices = new Set();
let before = 0, after = 0;
const perPrimitive = [];
for (let i = 0; i < primitives.length; i++) {
  const p = primitives[i], oldIndex = json.accessors[p.indices];
  if (!oldIndex || oldIndex.type !== 'SCALAR') throw new Error('Invalid indices for primitive ' + i);
  const indices = readDense(p.indices).values;
  const unique = [...new Set(indices)].sort((a, b) => a - b);
  if (!unique.length || unique.some(v => !Number.isInteger(v) || v < 0 || v >= vertexCount)) throw new Error('Out-of-range indices in primitive ' + i);
  const map = new Map(unique.map((v, n) => [v, n]));
  unique.forEach(v => usedVertices.add(v));
  before += vertexCount; after += unique.length; perPrimitive.push(unique.length);
  for (const [semantic, accessorId] of Object.entries(p.attributes)) {
    const old = json.accessors[accessorId], decoded = readDense(accessorId), compact = [];
    if (old.count !== vertexCount) throw new Error('Attribute count mismatch: ' + semantic);
    for (const v of unique) compact.push(...decoded.values.slice(v * decoded.components, (v + 1) * decoded.components));
    p.attributes[semantic] = denseAccessor(compact, old, 34962, semantic === 'POSITION');
  }
  p.indices = denseAccessor(indices.map(v => map.get(v)), oldIndex, 34963, false);
  for (const target of p.targets || []) for (const [semantic, id] of Object.entries(target)) {
    if (semantic !== 'POSITION') throw new Error('Unsupported morph target: ' + semantic);
    target[semantic] = sparseMorphAccessor(id, map, unique.length);
  }
}

const expanded = Buffer.concat([bin, Buffer.concat(appended)]);
const usedAccessors = new Set();
for (const mesh of json.meshes) for (const p of mesh.primitives) {
  usedAccessors.add(p.indices); Object.values(p.attributes).forEach(id => usedAccessors.add(id));
  for (const t of p.targets || []) Object.values(t).forEach(id => usedAccessors.add(id));
}
for (const animation of json.animations || []) for (const s of animation.samplers || []) { usedAccessors.add(s.input); usedAccessors.add(s.output); }
for (const skin of json.skins || []) if (skin.inverseBindMatrices != null) usedAccessors.add(skin.inverseBindMatrices);
const accessorMap = new Map(), keptAccessors = [];
json.accessors.forEach((a, i) => { if (usedAccessors.has(i)) { accessorMap.set(i, keptAccessors.length); keptAccessors.push(a); } });
for (const mesh of json.meshes) for (const p of mesh.primitives) {
  p.indices = accessorMap.get(p.indices);
  for (const [k, id] of Object.entries(p.attributes)) p.attributes[k] = accessorMap.get(id);
  for (const t of p.targets || []) for (const [k, id] of Object.entries(t)) t[k] = accessorMap.get(id);
}
for (const animation of json.animations || []) for (const s of animation.samplers || []) { s.input = accessorMap.get(s.input); s.output = accessorMap.get(s.output); }
for (const skin of json.skins || []) if (skin.inverseBindMatrices != null) skin.inverseBindMatrices = accessorMap.get(skin.inverseBindMatrices);
json.accessors = keptAccessors;

const usedViews = new Set();
for (const a of json.accessors) {
  if (a.bufferView != null) usedViews.add(a.bufferView);
  if (a.sparse) { usedViews.add(a.sparse.indices.bufferView); usedViews.add(a.sparse.values.bufferView); }
}
for (const image of json.images || []) if (image.bufferView != null) usedViews.add(image.bufferView);
const viewMap = new Map(), viewParts = [], keptViews = [];
let packedSize = 0;
json.bufferViews.forEach((bv, i) => {
  if (!usedViews.has(i)) return;
  const pad = (4 - packedSize % 4) % 4;
  if (pad) { viewParts.push(Buffer.alloc(pad)); packedSize += pad; }
  const start = bv.byteOffset || 0, data = expanded.subarray(start, start + bv.byteLength);
  if (data.length !== bv.byteLength) throw new Error('Buffer view out of range: ' + i);
  viewMap.set(i, keptViews.length); keptViews.push({ ...bv, buffer: 0, byteOffset: packedSize });
  viewParts.push(data); packedSize += data.length;
});
for (const a of json.accessors) {
  if (a.bufferView != null) a.bufferView = viewMap.get(a.bufferView);
  if (a.sparse) { a.sparse.indices.bufferView = viewMap.get(a.sparse.indices.bufferView); a.sparse.values.bufferView = viewMap.get(a.sparse.values.bufferView); }
}
for (const image of json.images || []) if (image.bufferView != null) image.bufferView = viewMap.get(image.bufferView);
json.bufferViews = keptViews;
const packed = Buffer.concat(viewParts);
json.buffers[0].byteLength = packed.length;
const jsonRaw = Buffer.from(JSON.stringify(json));
const jsonChunk = Buffer.concat([jsonRaw, Buffer.alloc((4 - jsonRaw.length % 4) % 4, 0x20)]);
const binChunk = Buffer.concat([packed, Buffer.alloc((4 - packed.length % 4) % 4)]);
const header = Buffer.alloc(12); header.write('glTF', 0); header.writeUInt32LE(2, 4);
const total = 12 + 8 + jsonChunk.length + 8 + binChunk.length; header.writeUInt32LE(total, 8);
const jh = Buffer.alloc(8); jh.writeUInt32LE(jsonChunk.length, 0); jh.writeUInt32LE(0x4e4f534a, 4);
const bh = Buffer.alloc(8); bh.writeUInt32LE(binChunk.length, 0); bh.writeUInt32LE(0x004e4942, 4);
fs.writeFileSync(output, Buffer.concat([header, jh, jsonChunk, bh, binChunk]));
console.log('Primitives: ' + primitives.length + '; vertex instances: ' + before + ' -> ' + after + ' (' + (100 * (1 - after / before)).toFixed(1) + '% fewer)');
console.log('Vertices per primitive: ' + perPrimitive.join(', '));
console.log('Source vertices retained: ' + usedVertices.size + '/' + vertexCount + '; morph targets: ' + morphCount);
console.log('GLB size: ' + (file.length / 1048576).toFixed(2) + ' -> ' + (fs.statSync(output).size / 1048576).toFixed(2) + ' MB');
