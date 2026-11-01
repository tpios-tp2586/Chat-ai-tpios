import { readFileSync, writeFileSync } from "node:fs";

const file = process.argv[2];
if (!file) throw new Error("Usage: node scripts/inspect-ara-animation.mjs <file.glb>");

const bytes = readFileSync(file);
let offset = 12;
let doc;
let binary;
while (offset < bytes.length) {
  const length = bytes.readUInt32LE(offset);
  const type = bytes.readUInt32LE(offset + 4);
  const chunk = bytes.subarray(offset + 8, offset + 8 + length);
  if (type === 0x4e4f534a) doc = JSON.parse(chunk.toString("utf8").trim());
  if (type === 0x004e4942) binary = chunk;
  offset += 8 + length;
}
if (!doc || !binary) throw new Error("Invalid GLB: JSON/BIN chunk missing");

const nodes = doc.nodes ?? [];
const nodeName = (index) => nodes[index]?.name ?? `node#${index}`;
const components = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 };
const dataView = new DataView(binary.buffer, binary.byteOffset, binary.byteLength);

function accessor(id) {
  const a = doc.accessors[id];
  const bv = doc.bufferViews[a.bufferView];
  const n = components[a.type];
  const stride = bv.byteStride ?? n * 4;
  if (a.componentType !== 5126 || stride !== n * 4) throw new Error(`Unsupported accessor ${id}`);
  const start = (bv.byteOffset ?? 0) + (a.byteOffset ?? 0);
  const values = [];
  for (let i = 0; i < a.count * n; i++) values.push(dataView.getFloat32(start + i * 4, true));
  return { values, count: a.count, components: n, type: a.type };
}

function track(animation, channel) {
  const sampler = animation.samplers[channel.sampler];
  const input = accessor(sampler.input).values;
  const output = accessor(sampler.output);
  const width = output.values.length / input.length;
  return { times: input, values: output.values, width };
}

function quatAt(t, tr) {
  const { times, values, width } = tr;
  if (width !== 4) return null;
  if (t <= times[0]) return values.slice(0, 4);
  const last = times.length - 1;
  if (t >= times[last]) return values.slice(last * 4, last * 4 + 4);
  let i = 1;
  while (i < times.length && times[i] < t) i++;
  const t0 = times[i - 1], t1 = times[i];
  const f = (t - t0) / (t1 - t0 || 1);
  const q = [
    values[(i - 1) * 4] + (values[i * 4] - values[(i - 1) * 4]) * f,
    values[(i - 1) * 4 + 1] + (values[i * 4 + 1] - values[(i - 1) * 4 + 1]) * f,
    values[(i - 1) * 4 + 2] + (values[i * 4 + 2] - values[(i - 1) * 4 + 2]) * f,
    values[(i - 1) * 4 + 3] + (values[i * 4 + 3] - values[(i - 1) * 4 + 3]) * f,
  ];
  const len = Math.hypot(...q) || 1;
  return q.map((v) => v / len);
}

function angleDeg(a, b) {
  if (!a || !b) return null;
  const dot = Math.min(1, Math.abs(a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]));
  return 2 * Math.acos(dot) * 180 / Math.PI;
}

const animations = doc.animations ?? [];
const byName = new Map(animations.map((a) => [String(a.name ?? "").toLowerCase(), a]));
const names = ["Idle", "Wave", "Talk", "TalkExplain", "AraListening", "AraThinking", "AraEmpathy", "AraLaugh", "Cheer", "Laugh"];
const report = [];
report.push(`GLB animations=${animations.length}`);

for (const name of names) {
  const animation = byName.get(name.toLowerCase());
  if (!animation) {
    report.push(`${name}: MISSING`);
    continue;
  }
  const channels = animation.channels.map((channel) => ({ channel, track: track(animation, channel) }));
  const duration = Math.max(...channels.flatMap(({ track }) => track.times));
  const rotations = channels.filter(({ channel }) => channel.target.path === "rotation");
  const paths = Object.entries(Object.groupBy(channels, ({ channel }) => channel.target.path)).map(([k, v]) => `${k}=${v.length}`).join(", ");
  report.push(`${name}: duration=${duration.toFixed(4)}s channels=${channels.length} rotations=${rotations.length} paths=[${paths}]`);
  if (name === "TalkExplain") {
    const byNode = new Map(rotations.map(({ channel, track }) => [channel.target.node, track]));
    const talk = byName.get("talk");
    const talkByNode = new Map((talk?.channels ?? []).filter((c) => c.target.path === "rotation").map((c) => [c.target.node, track(talk, c)]));
    const targets = ["Spine2", "Neck", "Head", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "RightHandIndex1", "RightHandMiddle1", "RightHandPinky1"];
    for (const target of targets) {
      const index = nodes.findIndex((n) => n.name === target);
      const explainTrack = byNode.get(index);
      const talkTrack = talkByNode.get(index);
      if (!explainTrack || !talkTrack) {
        report.push(`TalkExplain/${target}: track=${explainTrack ? "yes" : "NO"} talkTrack=${talkTrack ? "yes" : "NO"}`);
        continue;
      }
      let max = 0;
      for (let i = 0; i <= 20; i++) {
        const u = i / 20;
        const explainT = duration * u;
        const talkDuration = Math.max(...talkByNode.values().flatMap((tr) => tr.times));
        const talkT = talkDuration * u;
        max = Math.max(max, angleDeg(quatAt(explainT, explainTrack), quatAt(talkT, talkTrack)) ?? 0);
      }
      report.push(`TalkExplain/${target}: maxAngleDeltaVsTalk=${max.toFixed(3)}deg`);
    }
  }
}

const output = report.join("\n") + "\n";
console.log(output);
writeFileSync("output/animation-diagnostics.txt", output);
