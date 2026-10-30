import fs from "node:fs";

const root = process.argv[2] ?? "ara";
const files = {
  index: `${root}/src/core/anim/clips/index.ts`,
  emotes: `${root}/src/core/anim/clips/emotes.ts`,
  faces: `${root}/src/core/anim/clips/faces.ts`,
};

function replaceOnce(source, before, after, label) {
  const first = source.indexOf(before);
  if (first < 0 || source.indexOf(before, first + before.length) >= 0) {
    throw new Error(`Expected exactly one insertion point for ${label}`);
  }
  return source.slice(0, first) + after + source.slice(first + before.length);
}

for (const [name, file] of Object.entries(files)) {
  if (!fs.existsSync(file)) throw new Error(`Missing upstream source: ${file}`);
  const source = fs.readFileSync(file, "utf8");
  if (source.includes("talkExplain") || source.includes("talk_explain")) {
    throw new Error(`TalkExplain already exists in ${file}; refusing duplicate patch`);
  }
}

let index = fs.readFileSync(files.index, "utf8");
index = replaceOnce(
  index,
  "import { cheer, laugh, talk, wave } from './emotes';",
  "import { cheer, laugh, talk, talkExplain, wave } from './emotes';",
  "emotes import",
);
index = replaceOnce(index, "    talk,\n    mocap('cry'", "    talk,\n    talkExplain,\n    mocap('cry'", "clip registration");

let emotes = fs.readFileSync(files.emotes, "utf8");
emotes += `

/** A restrained, one-shot open-hand gesture for a spoken explanation. */
export const talkExplain: Clip = {
  id: 'talk_explain', name: 'TalkExplain', category: 'Emotes', duration: 2.8, loop: false,
  sample: (t) => {
    const progress = Math.max(0, Math.min(1, t / 2.8));
    const reach = Math.sin(progress * Math.PI);
    const base = talk.sample((t / 2.8) * TALK_LEN);
    const bones = { ...base.bones };
    fingers(bones, 3);
    return {
      ...base,
      bones,
      ik: {
        Right: {
          pos: v(-0.30 - 0.08 * reach, -0.18 + 0.08 * reach, 0.18 + 0.04 * reach),
          pole: v(-0.7, -1, -0.2),
          dir: v(-0.1, 0.2, 1),
          palm: v(0, 0, 1),
        },
      },
    };
  },
};
`;

let faces = fs.readFileSync(files.faces, "utf8");
faces = replaceOnce(
  faces,
  "  },\n  laugh: (t, d) => {",
  `  },
  talk_explain: (t, d) => {
    const speechTime = (t / d) * 6.4;
    const st = speechStress(speechTime);
    return { ...speechFace(speechTime), browInnerUp: 0.25 * st, browOuterUpLeft: 0.3 * st, browOuterUpRight: 0.3 * st };
  },
  laugh: (t, d) => {`,
  "TalkExplain facial mapping",
);

fs.writeFileSync(files.index, index);
fs.writeFileSync(files.emotes, emotes);
fs.writeFileSync(files.faces, faces);
console.log("Applied TalkExplain using exact, asserted source anchors.");
