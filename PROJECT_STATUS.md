# Chat AI TPiOS — Checkpoint

## Project rules
- **Branch:** `main` only. Inspect current source and repository state before every edit; never create or switch to another branch.
- **App:** SwiftUI + XcodeGen (`project.yml`). Codemagic workflow: IPA-only.
- **Build permission:** Never start Codemagic or GitHub Actions without explicit user permission. User runs Codemagic builds.
- **Keep stable:** Text Chat, provider APIs, chat history, Gemini Live voice, Chibi/robot face, settings and theme.
- **Engineering:** Minimal changes, no unnecessary dependencies, no unrelated cleanup or refactoring.
- **Diagnostics / in-app log panel:** The panel is a targeted collection tool, not a full console. Forward only log categories required for the current test question; keep unrelated/internal diagnostics out of the panel. Suppress verbose, repetitive, duplicate, and already-resolved logs. Keep error details concise but actionable. Preserve the copy-log and clear-log controls. Before requesting logs, specify the exact prefix/category needed. Inspect existing logs and saved results first; never repeat known inventories.

## Progress rules — mandatory
This file is the source of truth for project progress.
- Every work item must have a status, objective, acceptance criteria, test/evidence, result, and next action.
- Allowed statuses: `NOT STARTED`, `IN PROGRESS`, `BLOCKED`, `DONE`.
- Mark an item `DONE` only after its acceptance criteria are met and the result is supported by a test, log, source inspection, or explicit user confirmation.
- A completed item is locked. Do not repeat its tests or change its implementation unless a new defect, regression, or explicit user request justifies reopening it.
- A test must answer a named question. Do not run exploratory tests without recording the question and expected decision.
- After each test, record the date, exact test, evidence/log reference, outcome, conclusion, and next action here before moving on.
- After a code change, test only the changed behavior and directly affected regression paths. Do not rerun unrelated completed tests.
- Never mark work done merely because code was edited or a build succeeded. Completion requires behavior-level verification.
- At each handoff, report: completed, current item, blockers, and the single next step.

## Alina — scope and locked decisions

### Completed and locked
| ID | Work item | Status | Acceptance evidence / decision |
|---|---|---|---|
| AL-01 | Full-body framing and visible size | DONE | User confirmed Alina is fully visible. Lock current framing; do not retune without a new defect/request. |
| AL-02 | Rotation | DONE | User confirmed rotation works. Preserve horizontal drag sensitivity `0.01`. |
| AL-03 | Position / move gesture | DONE | User confirmed current movement is acceptable. Preserve 0.30s hold + drag and direct anchor updates. |
| AL-04 | Zoom | DONE | Current pinch zoom and persisted setting are accepted. Preserve key `alina_avatar_zoom_scale_v1` and clamp 0.7...4.5. |
| AL-05 | Animation playback start/stop | DONE | Three prior device tests confirmed: still after load, moves while AI speaks, stops when AI finishes. Do not repeat these tests. |

### Locked implementation values
- Model: `ChatAI/Resources/Alina.usdz`; view implementation: `ChatAI/AlinaAvatarView.swift`.
- Framing: `targetHeight = 3.20`; preserve fit-scale calculation, anchor framing formula, upward adjustment `targetHeight * 0.20`, and depth `z = -2.8`.
- Zoom: preserve zoom pivot and persisted key `alina_avatar_zoom_scale_v1`, clamp 0.7...4.5.
- Position: preserve persisted keys `alina_avatar_position_x_v1` and `alina_avatar_position_y_v1`.
- Rotation: preserve horizontal drag sensitivity `0.01`.
- Move gesture: preserve 0.30s hold and current direct RealityKit anchor update.
- Playback: currently plays `skin0` clip 0 as a loop while `isSpeaking` is true and pauses when false. Start/stop behavior is verified; semantic quality and animation selection are not yet approved.

### Animation investigation and implementation plan
| ID | Work item | Status | Objective and acceptance criteria | Test / evidence already available | Next action |
|---|---|---|---|---|---|
| AN-01 | Inventory sampled clips `skin0#0–#18` | DONE | Determine whether entries contain distinct sampled frame data. | Existing logs: each has 2717 frames, 101 joints, 0.008333334s frame interval, 81 moving joints; #1–#18 report exact duplicate of #0. One shared sampled motion is evidenced, not 19 unique actions. | Do not request or re-run these frame logs. |
| AN-02 | Inspect `AnimationGroup #19/#20` | DONE | Determine whether either group contains independent child animations or merely wraps the same sampled motion. | User device logs: `skin0#19` and `skin0#20` each contain exactly one `SampledAnimation<JointTransforms>` child; both are 2717 frames, 101 joints, 0.008333334s interval, and exact duplicates of `skin0#0`. Both groups are 22.633333s and have the same child name `_359960820992_TempMotion`. | Locked; do not inspect or replay these groups again. Continue to AN-03. |
| AN-03 | Build a unique-animation catalogue | DONE | Catalogue animation definitions across the full entity hierarchy; identify owners, paths, targets, duration, definition types and distinct playable motions. Do not count duplicate wrappers as separate actions. | User's 2026-11-11 device audit: `entityReferences=50`, `uniqueSampled=1`, `duplicateSampled=20`, `nonEmptyGroups=3`, `emptyGroups=20`, `unsupported=9`. The one unique sampled track is owned by `skin0#0`: 2,717 frames, 101 joints, 0.008333334s interval, 81 moving joints, duration 22.633333s. The 20 sampled entries are exact duplicates; the two non-empty groups under `skin0#19/#20` wrap that same sampled track. Three non-empty groups are not three unique motions. Nine `AnimationView` references are reported as unsupported by the typed sampler audit and target the same nested `skin0` animation through progressively narrower hierarchy paths; they are not counted as additional sampled tracks. Empty groups contain no playable child motion. Recursive hierarchy inventory is now answered; visual semantics remain unknown. | Locked: do not repeat the inventory or request more metadata logs. Proceed to AN-04: visually classify the one unique motion. Only reopen AN-03 if a new model asset or a concrete inventory defect appears. |
| AN-04 | Determine body-control capability | IN PROGRESS | Inspect the rig and determine whether body parts / joint groups (arms, legs, shoulders, neck, torso) can be controlled independently or selectively, including how direct joint control interacts with the imported full-body animation. | User confirmed whole-body sway and movement of legs, arms, shoulders and neck. Source inspection confirms ChatAI currently only plays/pauses `skin0` clip 0; there is no direct joint-control implementation. RealityKit exposes runtime `ModelEntity.jointNames` and `jointTransforms`; active animations may override direct transform writes. `FromToByAnimation<JointTransforms>` supports a selected `jointNames` list. `SkeletalPosesComponent` is iOS 18+, while app deployment target is iOS 16, so it cannot be the sole path. | User device log (2026-11-11 12:45:37): `skin0` is `RealityKit.ModelEntity`; 101 runtime joints and 101 transforms; sampled animation also has 101 joints; `runtimeNamesMatchSample=true`. All 101 indexed hierarchical joint paths were captured. This proves the runtime rig is present and the animation's joint ordering matches it. The `n34...n134` paths are structural node paths, not yet semantic body-part labels. A source-only, read-only diagnostic was added to resolve each joint's nearest indexed ancestor and report depth plus initial local translation in 18-joint chunks; it has not been compiled or device-tested. | User runs one focused Chat Voice build and shares `[ALINA RIG AUDIT] hierarchy joints` chunks. Interpret parent/depth/local-translation map, then design one minimal reversible single-joint control probe. Do not add idle/background motion. |
| AN-05 | Prove selective body-part control | NOT STARTED | Demonstrate reliable, controllable movement of selected joints / body groups (arms, legs, shoulders, neck, torso), with explicit start, stop and reset; resolve conflicts with the imported full-body track. | Requires AN-04 skeleton and playback-path inspection. | Run a minimal joint-control experiment; do not build a general controller yet. |
| AN-06 | Build deliberate body actions | NOT STARTED | Combine verified controllable joints into a small set of intentional body actions with predictable timing, transitions and interruption. | Requires AN-05 to pass. | Implement only actions that have been demonstrated to work. |
| AN-07 | Verify body control in Chat Voice | NOT STARTED | Confirm actions start, stop and transition reliably; preserve framing, zoom, rotation, move gesture, chatbot and Gemini Live. | No new body-control test has been run. Prior AL-05 playback evidence remains valid unless its code path changes. | User runs the authorized Codemagic/device test; record results here. |

## Test record
Append a concise entry after each new test. Do not overwrite prior evidence.
| Date | Work ID | Question / test | Evidence reference | Result / conclusion | Next action |
|---|---|---|---|---|---|
| 2026-11-11 | AN-01 | Compare sampled frame data for `skin0#0–#18`. | Chat logs supplied by user in Alina investigation conversation. | All sampled frame data are exact duplicates of #0; not 19 distinct motions. | Locked; no retest. |
| 2026-11-11 | AN-02 | Inspect the children of `skin0#19/#20` and compare sampled joint data with `skin0#0–#18`. | User-supplied device logs in this conversation. | Both groups contain one sampled joint animation child; each child is an exact duplicate of `skin0#0`. AN-02 resolved: these are wrappers, not independent motions. | Locked; proceed to the full hierarchy inventory. |
| 2026-11-11 | AN-03 | Make one device run sufficient to collect the complete unique-animation audit without log truncation. | Inspected `main` at `cc14f6d`; found per-clip logs and a 150-line rolling diagnostic buffer. Commits `a75c380`, `99d1c3c`, `a1b823a`, `f20209c`, and `a01ee20` consolidate the audit, preserve audit lines, include clip metadata, and scan all animation references recursively across the hierarchy instead of assuming a `skin0` index range. | Source-only diagnostic changes in `AlinaAvatarView.swift` and `CompanionChatView.swift`. All entities and all available animation definitions are scanned in one pass; duplicate sampled joint tracks are compared by frame data. Only audit, playback-test, and actionable error categories are forwarded. Not built or device-tested. | User runs one Codemagic/device build and shares the three specified prefixes. |
| 2026-11-11 | AN-03 | Verify the recursive audit against the complete Alina hierarchy and count genuinely unique sampled motions. | User-provided Chat Voice device log at 10:05:32, including `[ALINA ANIMATION AUDIT] totals` and owner/clip summaries. | Full hierarchy totals: 50 entity references; 1 unique sampled track; 20 exact sampled duplicates; 3 non-empty groups; 20 empty groups; 9 unsupported `AnimationView` definitions. The unique track is 2,717 frames / 101 joints / 81 moving joints / 22.633333s. AN-03 complete. | Move to AN-04; do not repeat inventory. |
| 2026-11-11 | AN-04 | User describes the visible unique Alina motion. | User observation in chat: body sways side to side; legs, arms, shoulders and neck all move. | Whole-body movement is visually confirmed. This does not establish independent control of those body parts. | Inspect skeleton and animation application path; prove selective control before designing actions. |
| 2026-11-11 | AN-04 | Inspect current animation application path and determine a supported route for selective joint control. | Inspected `ChatAI/AlinaAvatarView.swift` on `main` at source blob `2ae0436`; inspected `project.yml` (iOS deployment target 16.0); Apple RealityKit docs for `HasModel.jointTransforms`, `JointTransforms`, `FromToByAnimation.jointNames`, and `SkeletalPosesComponent`. | Current code only starts/pauses the imported full-body `skin0#0` animation; no direct joint manipulation exists. RealityKit exposes indexed joint names/transforms and a joint-name-scoped `FromToByAnimation<JointTransforms>` route. Apple warns active animations may override direct `jointTransforms` writes. `SkeletalPosesComponent` is iOS 18+, so it is not a universal solution for this iOS 16 deployment target. Added focused rig audit logging in `ChatAI/AlinaAvatarView.swift` (commit `5468e2ee1a078c417521c2d5b611f5d3d7e11b7b`): runtime type, runtime joint/transform counts, runtime-vs-sampled name match, and indexed imported joint names in short chunks. This is source-only and has not been compiled or device-tested. | User runs one build and shares only `[ALINA RIG AUDIT]` lines. Then map the rig and decide the smallest single-joint control test. |
| 2026-11-11 | AN-04 | Verify the runtime skin entity exposes the same skeleton as the sampled animation. | User-provided Log Tool output from Chat Voice at 12:45:37: `[ALINA RIG AUDIT]` owner/runtimeType/counts/name-match and joint index ranges 0–100. | `skin0` is a `RealityKit.ModelEntity`; runtime joints=101, transforms=101; sampled joints=101; runtime names exactly match sampled names. All 101 hierarchical paths were captured in order. Rig availability and runtime/sample mapping are confirmed. The numeric node paths do not yet identify semantic body parts or prove selective control. | Derive the joint tree (parent/child/depth) and determine a safe minimal control probe. Keep AN-04 open until controllability and body-part mapping are established. |
| Previously confirmed | AL-05 | Verify playback at load, while speaking, and after speaking ends. | Three device tests explicitly confirmed by user. | All three behaviors pass. | Locked; no retest unless playback code changes or regression appears. |

## Deferred — only after AN-07 passes
- Background / idle movement is explicitly deferred. Do not implement continuous idle, listening, thinking, speaking or other background loops during AN-04 through AN-07.
- First prove deliberate, user/AI-triggered body control and verify it in Chat Voice. Only then plan a separate background-motion phase.

## Build and release
- IPA-only output.
- User runs Codemagic. Never trigger builds or GitHub Actions without explicit permission.
- Do not add ZIP artifacts.


## Diagnostic log integrity — AN-04 (focused one-run test)
- **Purpose:** collect only the runtime skeleton mapping needed to decide whether selective body-part control is feasible. This is not a general app/voice console.
- **Allowed entries in the in-app Log Tool:**
  - `[INFO]` — one screen-open marker.
  - `[ALINA RIG AUDIT]` — runtime entity type, runtime joint/transform counts, sampled-vs-runtime joint-name match, and indexed hierarchy entries containing joint path, nearest parent index, depth, and initial local translation (chunked).
  - `[ALINA ERROR]` — model missing/load failure only.
- **Everything else is excluded:** routine `[VOICE]` and `[TEXT]`, status/transcript events, mesh/node dumps, layout/gesture debug, scale/framing traces, animation playback chatter, and the already-completed `[ALINA ANIMATION AUDIT]` inventory. Do not re-enable AN-03 inventory.
- **Retention:** no rolling 150-line eviction; retain the complete required diagnostic set for the current screen session until Clear is pressed.
- **Copy behavior:** display and Copy All use the same log text; Copy Selected copies only the highlighted text; Clear empties the displayed/copied log and selection. Preserve all three controls.
- **Next user test (one build only):** open Chat Voice once and wait until Alina finishes loading. Copy the `[ALINA RIG AUDIT]` output, including every `hierarchy joints` chunk. Confirm there are no `[VOICE]`, `[TEXT]`, `[ALINA ANIMATION AUDIT]`, mesh, or layout/debug dumps. No need to repeat Copy Selected validation unless that control has regressed.
- **Evidence to send:** preferably Copy All; it should include all `[ALINA RIG AUDIT]` lines. If the full list is lengthy, Copy Selected can send a specific range, but preserve the joint index labels so ordering is unambiguous.
- **Acceptance:** the complete rig audit is present and copyable without unrelated noise or missing lines. Only after this passes, interpret the joint map and design one minimal selective-control experiment.
- **Do not ask for or collect any other logs in this AN-04 run.**
