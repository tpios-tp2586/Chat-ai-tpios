import { readFileSync, writeFileSync, statSync } from "node:fs";

const file = process.argv[2];
if (!file) throw new Error("Usage: node scripts/verify-glb.mjs <file.glb>");

const bytes = readFileSync(file);
if (bytes.toString("ascii", 0, 4) !== "glTF") {
  throw new Error("Not a binary glTF file");
}

const version = bytes.readUInt32LE(4);
const declaredLength = bytes.readUInt32LE(8);
if (version !== 2 || declaredLength !== bytes.length) {
  throw new Error(`Invalid GLB header: version=${version}, length=${declaredLength}/${bytes.length}`);
}

let offset = 12;
let document;
while (offset < bytes.length) {
  const length = bytes.readUInt32LE(offset);
  const type = bytes.readUInt32LE(offset + 4);
  offset += 8;
  if (type === 0x4e4f534a) {
    document = JSON.parse(bytes.toString("utf8", offset, offset + length).replace(/\\0+$/, "").trim());
    break;
  }
  offset += length;
}

if (!document) throw new Error("GLB JSON chunk not found");

const skins = document.skins ?? [];
const animations = document.animations ?? [];
const joints = skins.reduce((sum, skin) => sum + (skin.joints?.length ?? 0), 0);
const animationNames = animations.map((animation, index) => animation.name || `animation_${index + 1}`);
const nodeNames = (document.nodes ?? []).map(node => node.name).filter(Boolean);
const report = [
  `File: ${file}`,
  `Size: ${(statSync(file).size / 1024 / 1024).toFixed(2)} MB`,
  `GLB version: ${version}`,
  `Skins: ${skins.length}`,
  `Joints: ${joints}`,
  `Animations: ${animations.length}`,
  `Animation names: ${animationNames.join(", ") || "none"}`,
  `Named nodes: ${nodeNames.slice(0, 80).join(", ")}`
].join("\n");

console.log(report);
writeFileSync("output/verification-report.txt", report + "\n");

if (skins.length === 0 || joints === 0) {
  throw new Error("Rig verification failed: no skinned skeleton found");
}
if (animations.length === 0) {
  throw new Error("Animation verification failed: no animation tracks found");
}
