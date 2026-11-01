import fs from "node:fs";
import path from "node:path";

const [input, outputDir] = process.argv.slice(2);
if (!input || !outputDir) {
  console.error("Usage: node split-glb-animations.mjs input.glb output-dir");
  process.exit(2);
}

const bytes = fs.readFileSync(input);
if (bytes.toString("ascii", 0, 4) !== "glTF" || bytes.readUInt32LE(4) !== 2 || bytes.readUInt32LE(8) !== bytes.length) {
  throw new Error("Expected a valid binary glTF 2.0 (.glb) file");
}

let offset = 12;
let json;
let binary;
while (offset < bytes.length) {
  const length = bytes.readUInt32LE(offset);
  const type = bytes.readUInt32LE(offset + 4);
  const chunk = bytes.subarray(offset + 8, offset + 8 + length);
  if (type === 0x4E4F534A) json = JSON.parse(chunk.toString("utf8").trim());
  if (type === 0x004E4942) binary = Buffer.from(chunk);
  offset += 8 + length;
}
if (!json || !binary || json.buffers?.length !== 1) throw new Error("GLB is missing its JSON or embedded binary buffer");

const requiredNames = [
  "Idle", "Wave", "Talk", "TalkExplain", "AraListening", "AraThinking", "AraEmpathy", "AraLaugh",
  "Walk", "Run", "Walk backwards", "Strafe left", "Strafe right", "Jump start", "Jump (in air)", "Jump land", "Sit down (chair)", "Sit idle (chair)", "Stand up (chair)", "Lie down", "Sleep", "Turn left 45°", "Turn left 90°", "Turn right 45°", "Turn right 90°", "Full turn 360°", "Ride horse (trot)"
];
const optionalNames = ["Cheer", "Laugh", "Cry"];
const findAnimation = name => (json.animations ?? []).find(item => item.name?.toLowerCase() === name.toLowerCase());
const selected = [
  ...requiredNames.map(name => {
    const animation = findAnimation(name);
    if (!animation) throw new Error("Required animation not found in GLB: " + name);
    return { name, animation, optional: false };
  }),
  ...optionalNames.map(name => ({ name, animation: findAnimation(name), optional: true })),
];

const componentCounts = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 };
const appended = [];
let appendedLength = 0;

function readAccessor(id) {
  const accessor = json.accessors[id];
  if (!accessor || accessor.componentType !== 5126 || accessor.sparse || accessor.bufferView == null) {
    throw new Error("Unsupported animation accessor " + id);
  }
  const components = componentCounts[accessor.type];
  if (!components) throw new Error("Unsupported accessor type " + accessor.type);
  const bufferView = json.bufferViews[accessor.bufferView];
  const stride = bufferView.byteStride ?? components * 4;
  if (stride !== components * 4) throw new Error("Unexpected byteStride in animation accessor " + id);
  const start = (bufferView.byteOffset ?? 0) + (accessor.byteOffset ?? 0);
  const dataView = new DataView(binary.buffer, binary.byteOffset, binary.byteLength);
  const values = [];
  for (let i = 0; i < accessor.count * components; i++) values.push(dataView.getFloat32(start + i * 4, true));
  return { accessor, values, components };
}

function appendFloatAccessor(values, type, includeBounds) {
  const padding = (4 - (binary.length + appendedLength) % 4) % 4;
  if (padding) { appended.push(Buffer.alloc(padding)); appendedLength += padding; }
  const data = Buffer.alloc(values.length * 4);
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  values.forEach((value, index) => view.setFloat32(index * 4, value, true));
  const bufferViewIndex = json.bufferViews.length;
  json.bufferViews.push({ buffer: 0, byteOffset: binary.length + appendedLength, byteLength: data.length });
  appended.push(data);
  appendedLength += data.length;
  const accessor = {
    bufferView: bufferViewIndex,
    componentType: 5126,
    count: values.length / componentCounts[type],
    type,
  };
  if (includeBounds) {
    const components = componentCounts[type];
    accessor.min = Array(components).fill(Infinity);
    accessor.max = Array(components).fill(-Infinity);
    values.forEach((value, index) => {
      const component = index % components;
      accessor.min[component] = Math.min(accessor.min[component], value);
      accessor.max[component] = Math.max(accessor.max[component], value);
    });
  }
  json.accessors.push(accessor);
  return json.accessors.length - 1;
}

const tracksByTarget = new Map();
const timeline = [];
let cursor = 0;
for (const item of selected) {
  const { name, animation, optional } = item;
  if (!animation) {
    if (optional) {
      console.log("Skipped optional clip " + name + ": not found in source GLB");
      continue;
    }
    throw new Error("Required animation not found in GLB: " + name);
  }

  const trackMap = new Map();
  let duration = 0;
  try {
    for (const channel of animation.channels) {
      const sampler = animation.samplers[channel.sampler];
      const input = readAccessor(sampler.input);
      const output = readAccessor(sampler.output);
      const key = channel.target.node + ":" + channel.target.path;
      if (trackMap.has(key)) throw new Error("duplicate track " + key);
      const times = input.values;
      if (times.length < 2 || times[0] !== 0) throw new Error(key + " must start at t=0");
      if (sampler.interpolation !== "LINEAR") throw new Error(key + " uses unsupported interpolation " + sampler.interpolation);
      if (output.values.length % times.length !== 0) throw new Error(key + " input/output count mismatch");
      const valuesPerKeyframe = output.values.length / times.length;
      if (channel.target.path !== "weights" && valuesPerKeyframe !== output.components) {
        throw new Error(key + " has an unexpected output shape");
      }
      duration = Math.max(duration, times[times.length - 1]);
      trackMap.set(key, {
        times,
        values: output.values,
        outputType: output.accessor.type,
        valuesPerKeyframe,
      });
    }
  } catch (error) {
    if (optional) {
      console.log("Skipped optional clip " + name + ": " + error.message);
      continue;
    }
    throw new Error(name + ": " + error.message);
  }

  if (trackMap.size === 0) {
    if (optional) {
      console.log("Skipped optional clip " + name + ": no animation channels");
      continue;
    }
    throw new Error(name + " has no animation channels");
  }

  const channelMismatch = tracksByTarget.size > 0 &&
    (trackMap.size !== tracksByTarget.size || [...tracksByTarget.keys()].some(key => !trackMap.has(key)));
  if (channelMismatch) {
    if (optional) {
      console.log("Skipped optional clip " + name + ": rig channels differ from the Ara timeline");
      continue;
    }
    throw new Error(name + " does not animate the same rig channels as the other clips");
  }

  let shapeMismatch = null;
  for (const [key, track] of trackMap) {
    const existing = tracksByTarget.get(key);
    if (existing?.length && (existing[0].outputType !== track.outputType || existing[0].valuesPerKeyframe !== track.valuesPerKeyframe)) {
      shapeMismatch = key;
      break;
    }
  }
  if (shapeMismatch) {
    if (optional) {
      console.log("Skipped optional clip " + name + ": output shape changed for " + shapeMismatch);
      continue;
    }
    throw new Error("Output shape changed for " + shapeMismatch);
  }

  if (tracksByTarget.size === 0) {
    for (const key of trackMap.keys()) tracksByTarget.set(key, []);
  }
  for (const [key, track] of trackMap) {
    const list = tracksByTarget.get(key);
    const shiftedTimes = track.times.map((time, index) => cursor + time + (cursor > 0 && index === 0 ? 0.0001 : 0));
    list.push({ times: shiftedTimes, values: track.values, outputType: track.outputType, valuesPerKeyframe: track.valuesPerKeyframe });
  }
  const clipStart = cursor + (cursor > 0 ? 0.0001 : 0);
  timeline.push({ name: animation.name, start: clipStart, end: cursor + duration, duration: duration - (clipStart - cursor) });
  cursor += duration;
}

const samplers = [];
const channels = [];
for (const [key, segments] of tracksByTarget) {
  const times = [];
  const values = [];
  const outputType = segments[0].outputType;
  for (const segment of segments) {
    if (times.length && segment.times[0] <= times[times.length - 1]) throw new Error("Non-increasing timeline for " + key);
    times.push(...segment.times);
    values.push(...segment.values);
  }
  const inputAccessor = appendFloatAccessor(times, "SCALAR", true);
  const outputAccessor = appendFloatAccessor(values, outputType, true);
  const samplerIndex = samplers.length;
  samplers.push({ input: inputAccessor, output: outputAccessor, interpolation: "LINEAR" });
  const parts = key.split(":");
  channels.push({ sampler: samplerIndex, target: { node: Number(parts[0]), path: parts[1] } });
}

json.animations = [{ name: "AraConversation", samplers, channels }];
const outputBinary = Buffer.concat([binary, ...appended]);
json.buffers[0].byteLength = outputBinary.length;
const jsonRaw = Buffer.from(JSON.stringify(json));
const jsonChunk = Buffer.concat([jsonRaw, Buffer.alloc((4 - jsonRaw.length % 4) % 4, 0x20)]);
const binaryChunk = Buffer.concat([outputBinary, Buffer.alloc((4 - outputBinary.length % 4) % 4)]);
const header = Buffer.alloc(12);
header.write("glTF", 0);
header.writeUInt32LE(2, 4);
header.writeUInt32LE(12 + 8 + jsonChunk.length + 8 + binaryChunk.length, 8);
const jsonHeader = Buffer.alloc(8);
jsonHeader.writeUInt32LE(jsonChunk.length, 0);
jsonHeader.writeUInt32LE(0x4E4F534A, 4);
const binaryHeader = Buffer.alloc(8);
binaryHeader.writeUInt32LE(binaryChunk.length, 0);
binaryHeader.writeUInt32LE(0x004E4942, 4);

fs.mkdirSync(outputDir, { recursive: true });
const output = path.join(outputDir, "Ara-Avatar.glb");
fs.writeFileSync(output, Buffer.concat([header, jsonHeader, jsonChunk, binaryHeader, binaryChunk]));
const manifest = { fps: 30, totalDuration: cursor, clips: timeline };
fs.writeFileSync(path.join(outputDir, "animation-timeline.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log("Created one sequential animation timeline (" + cursor.toFixed(4) + "s): " +
  timeline.map(item => item.name + " " + item.start.toFixed(4) + "-" + item.end.toFixed(4) + "s").join(", "));
console.log("Merged " + channels.length + " rig tracks from " + selected.length + " source clips.");
