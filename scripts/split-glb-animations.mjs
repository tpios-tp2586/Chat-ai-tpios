import fs from "node:fs";
import path from "node:path";

const [input, outputDir] = process.argv.slice(2);
if (!input || !outputDir) {
  console.error("Usage: node scripts/split-glb-animations.mjs input.glb output-dir");
  process.exit(2);
}

const data = fs.readFileSync(input);
if (data.toString("ascii", 0, 4) !== "glTF" || data.readUInt32LE(4) !== 2) {
  throw new Error("Expected a binary glTF 2.0 (.glb) file");
}

let offset = 12;
let json = null;
let binaryChunk = null;
while (offset < data.length) {
  const length = data.readUInt32LE(offset);
  const type = data.readUInt32LE(offset + 4);
  const chunk = data.subarray(offset + 8, offset + 8 + length);
  if (type === 0x4E4F534A) json = JSON.parse(chunk.toString("utf8").trim());
  if (type === 0x004E4942) binaryChunk = chunk;
  offset += 8 + length;
}
if (!json || !binaryChunk) throw new Error("GLB is missing JSON or BIN chunk");

fs.mkdirSync(outputDir, { recursive: true });

function writeGLB(name, animations) {
  const jsonBytes = Buffer.from(JSON.stringify({ ...json, animations }));
  const jsonPadding = (4 - jsonBytes.length % 4) % 4;
  const paddedJson = Buffer.concat([jsonBytes, Buffer.alloc(jsonPadding, 0x20)]);
  const binPadding = (4 - binaryChunk.length % 4) % 4;
  const paddedBin = Buffer.concat([binaryChunk, Buffer.alloc(binPadding)]);
  const totalLength = 12 + 8 + paddedJson.length + 8 + paddedBin.length;
  const header = Buffer.alloc(12);
  header.write("glTF", 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(totalLength, 8);
  const jsonHeader = Buffer.alloc(8);
  jsonHeader.writeUInt32LE(paddedJson.length, 0);
  jsonHeader.writeUInt32LE(0x4E4F534A, 4);
  const binHeader = Buffer.alloc(8);
  binHeader.writeUInt32LE(paddedBin.length, 0);
  binHeader.writeUInt32LE(0x004E4942, 4);
  fs.writeFileSync(path.join(outputDir, `Ara-${name}.glb`),
    Buffer.concat([header, jsonHeader, paddedJson, binHeader, paddedBin]));
}

const clips = ["Idle", "Wave", "Talk"].map(name => {
  const animation = (json.animations ?? []).find(a => a.name?.toLowerCase() === name.toLowerCase());
  if (!animation) throw new Error(`Required animation not found: ${name}`);
  return animation;
});

for (const [index, name] of ["Idle", "Wave", "Talk"].entries()) {
  writeGLB(name, [clips[index]]);
  console.log(`Created isolated ${name} clip`);
}
