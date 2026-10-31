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
  if (source.includes("talkExplain") || source.includes("talk_explain") || source.includes("araListening")) {
    throw new Error(`TalkExplain already exists in ${file}; refusing duplicate patch`);
  }
}

let index = fs.readFileSync(files.index, "utf8");
index = replaceOnce(
  index,
  "import { cheer, laugh, talk, wave } from './emotes';",
  "import { araEmpathy, araLaugh, araListening, araThinking, cheer, laugh, talk, talkExplain, wave } from './emotes';",
  "emotes import",
);
index = replaceOnce(index, "    talk,\n    mocap('cry'", "    talk,\n    talkExplain,\n    araListening,\n    araThinking,\n    araEmpathy,\n    araLaugh,\n    mocap('cry'", "clip registration");

let emotes = fs.readFileSync(files.emotes, "utf8");
emotes += `

/** A restrained, one-shot open-hand gesture for a spoken explanation. */
export const talkExplain: Clip = {
  id: 'talk_explain', name: 'TalkExplain', category: 'Emotes', duration: 2.8, loop: false,
  sample: (t) => {
    const progress = Math.max(0, Math.min(1, t / 2.8));
    // Lift, briefly present the open hand at chest height, then lower it smoothly.
    const lift = progress < 0.28
      ? 1 - Math.pow(1 - progress / 0.28, 3)
      : progress > 0.68
        ? Math.pow(1 - (progress - 0.68) / 0.32, 3)
        : 1;
    const base = talk.sample((t / 2.8) * TALK_LEN);
    const bones = { ...base.bones };
    fingers(bones, 2);
    return {
      ...base,
      bones,
      ik: {
        Right: {
          // Chest-space target: move the right hand from the upper abdomen to chest level.
          pos: v(-0.31 - 0.07 * lift, -0.14 + 0.16 * lift, 0.12 + 0.12 * lift),
          pole: v(-0.75, -0.35, -0.15),
          dir: v(-0.12, 0.08, 1),
          palm: v(0, 0, 1),
        },
      },
    };
  },
};
`;


emotes += `

/** Subtle full-body loops for conversational listening, thinking and empathy. */
export const araListening: Clip = {
  id: 'ara_listening', name: 'AraListening', category: 'Emotes', duration: 3.2, loop: true,
  sample: (t) => {
    const base = idle.sample(t), a = (t / 3.2) * Math.PI * 2;
    const head = base.bones.Head ?? [0, 0, 0], neck = base.bones.Neck ?? [0, 0, 0];
    return { ...base, bones: { ...base.bones,
      Neck: [neck[0] + 0.5, neck[1], neck[2] + 0.8 * Math.sin(a)],
      Head: [head[0] + 0.8 * Math.sin(a), head[1] + 1.5 * Math.sin(a * 0.5), head[2] + 2.2],
    } };
  },
};

export const araThinking: Clip = {
  id: 'ara_thinking', name: 'AraThinking', category: 'Emotes', duration: 3.2, loop: true,
  sample: (t) => {
    const base = idle.sample(t), a = (t / 3.2) * Math.PI * 2;
    const head = base.bones.Head ?? [0, 0, 0], neck = base.bones.Neck ?? [0, 0, 0];
    const spine = base.bones.Spine2 ?? [0, 0, 0];
    return { ...base, bones: { ...base.bones,
      Spine2: [spine[0] - 0.8, spine[1], spine[2]],
      Neck: [neck[0] - 1.2, neck[1], neck[2] - 0.8],
      Head: [head[0] - 2.5 + 0.7 * Math.sin(a), head[1] + 2.0, head[2] - 3.0],
    } };
  },
};

export const araEmpathy: Clip = {
  id: 'ara_empathy', name: 'AraEmpathy', category: 'Emotes', duration: 3.2, loop: true,
  sample: (t) => {
    const base = idle.sample(t), a = (t / 3.2) * Math.PI * 2;
    const head = base.bones.Head ?? [0, 0, 0], neck = base.bones.Neck ?? [0, 0, 0];
    const spine = base.bones.Spine2 ?? [0, 0, 0];
    return { ...base, bones: { ...base.bones,
      Spine2: [spine[0] - 1.0, spine[1], spine[2]],
      Neck: [neck[0] + 0.5, neck[1], neck[2] + 0.8],
      Head: [head[0] + 0.6 * Math.sin(a), head[1], head[2] + 4.0],
    } };
  },
};

/** Short, restrained laugh; app playback returns to the active conversation clip. */
export const araLaugh: Clip = {
  id: 'ara_laugh', name: 'AraLaugh', category: 'Emotes', duration: 2.4, loop: false,
  sample: (t) => {
    const base = idle.sample((t / 2.4) * 3.2);
    const pulse = Math.abs(Math.sin((t / 2.4) * Math.PI * 3));
    const spine = base.bones.Spine ?? [0, 0, 0], spine2 = base.bones.Spine2 ?? [0, 0, 0];
    const head = base.bones.Head ?? [0, 0, 0];
    return { ...base, bones: { ...base.bones,
      Spine: [spine[0] - 1.4 * pulse, spine[1], spine[2]],
      Spine2: [spine2[0] - 1.0 * pulse, spine2[1], spine2[2]],
      Head: [head[0] - 2.0 * pulse, head[1] + 1.2 * Math.sin(t * 2), head[2] + 1.5 * pulse],
    } };
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
