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
| AN-04 | Determine single-joint control and reset | DONE | Prove one joint can be controlled independently and restore the intended bind pose without disturbing the imported full-body animation. | Runtime rig is a `RealityKit.ModelEntity` with 101 joints/transforms matching the sampled animation. | User confirmed the index-49 probe visibly moves the left arm independently and restores both arms to horizontal shoulder height. Startup left-arm raise/lower remains correct. Source baseline fix verified on `main` at `b7b312f` / blob `6b95afb`. | Locked; do not repeat the probe or retest startup motion. Proceed to AN-05 with a separate mirrored-joint candidate. |
| AN-05 | Prove selective control of additional body parts | DONE | In one Chat Voice run, sweep every joint except the two confirmed arm-control joints; verify the remaining visible body regions respond without separate builds. | User's explicit device observation after the consolidated sweep: both legs, ankles, both arms, wrists, hands, fingers, chest, neck, head, mouth and eyes all visibly respond. Together with prior index-49/index-77 results, selective body control is confirmed across the complete visible rig. | Locked. Do not repeat the sweep or run per-part tests. Proceed to AN-06: design a small set of deliberate, coordinated body actions using the verified rig. |
| AN-06 | Build deliberate body actions | IN PROGRESS | Implement the user-approved first action set: wave greeting; nod/shake head; gentle head tilt; blink and facial expression; speech-linked mouth movement; coordinated hand and upper-body gestures. Motion must be slow, smooth, eased in/out, anatomically conservative, and coordinated across joints. | AN-05 DONE: user visually confirmed both legs, ankles, both arms, wrists, hands, fingers, chest, neck, head, mouth and eyes respond to the consolidated joint sweep. User approved the proposed action set and motion-quality constraints on 2026-11-11. | Inspect existing Chat Voice emotion/transcript state and Alina animation ownership; implement the smallest action controller without changing Gemini Live, chatbot, Chibi, framing or gestures. Keep idle/background motion deferred. |
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
| 2026-11-11 | AN-04 | Compile the new read-only hierarchy diagnostic. | User-provided Codemagic compiler output: `runtimeTransforms` is `[Transform]`, but `logJointHierarchy` initially declared `JointTransforms`. | Build failed at `AlinaAvatarView.swift:323` due to the parameter type mismatch. Corrected the helper signature to accept `[Transform]` in commit `9b2425fd817fec1d2d3907520380f3d6b864fbd3`. No runtime behavior changed. Fix is source-only and awaits a new user-run build. | Re-run Codemagic once; if compilation passes, collect only `[ALINA RIG AUDIT] hierarchy joints` output. |
| 2026-11-11 | AN-04 | Verify the runtime skin entity exposes the same skeleton as the sampled animation. | User-provided Log Tool output from Chat Voice at 12:45:37: `[ALINA RIG AUDIT]` owner/runtimeType/counts/name-match and joint index ranges 0–100. | `skin0` is a `RealityKit.ModelEntity`; runtime joints=101, transforms=101; sampled joints=101; runtime names exactly match sampled names. All 101 hierarchical paths were captured in order. Rig availability and runtime/sample mapping are confirmed. The numeric node paths do not yet identify semantic body parts or prove selective control. | Derive the joint tree (parent/child/depth) and determine a safe minimal control probe. Keep AN-04 open until controllability and body-part mapping are established. |
| 2026-11-11 | AN-04 | Add one reversible joint-scoped animation probe. | Inspected latest `AlinaAvatarView.swift` and `PROJECT_STATUS.md` on `main`; Apple RealityKit documentation confirms `FromToByAnimation<JointTransforms>.jointNames` scopes the animated pose to named joints and is available from iOS 15. Commit `a092a81e962300476c35de0180dc48643e4f0f25`; verified source blob `24b46a38329f9af5bebc687021455acc5e7faa48`. | Added a temporary index-49 probe with a 15° rotation, 0.65s duration and 0.85s restore. It is attempted only when the imported full-body animation is paused; the original transform array is restored after stopping the probe, and the probe is cancelled/restored before speaking playback resumes. This is source-only; no Codemagic build or device test was run. | User runs one idle Chat Voice build and reports the visible result plus only the `[ALINA RIG AUDIT]` single-joint probe lines. |\n| Previously confirmed | AL-05 | Verify playback at load, while speaking, and after speaking ends. | Three device tests explicitly confirmed by user. | All three behaviors pass. | Locked; no retest unless playback code changes or regression appears. |

## Deferred — only after AN-07 passes
- Background / idle movement is explicitly deferred. Do not implement continuous idle, listening, thinking, speaking or other background loops during AN-04 through AN-07.
- First prove deliberate, user/AI-triggered body control and verify it in Chat Voice. Only then plan a separate background-motion phase.

## Build and release
- IPA-only output.
- User runs Codemagic. Never trigger builds or GitHub Actions without explicit permission.
- Do not add ZIP artifacts.


| 2026-11-11 | AN-04 | Compile the temporary single-joint probe. | User-provided Codemagic output: `FromToByAnimation<JointTransforms>` has no member `create()` at `AlinaAvatarView.swift:362`; unrelated `ContentView.swift` warning says local `face` can be `let`. Apple RealityKit API documents `AnimationResource.generate(with:)` as the throwing resource factory. | Build failed before the runtime probe. Replaced the unsupported `definition.create()` call with guarded `try AnimationResource.generate(with: definition)`; probe parameters, joint index, playback gating, and restore logic remain unchanged. Source-only correction; no build run by assistant. | User runs one Codemagic build. If it compiles, perform the existing idle Chat Voice probe and report only its visual result plus `[ALINA RIG AUDIT]` probe lines. |

## Diagnostic log integrity — AN-04 (single-joint probe)
- **Purpose:** determine whether one indexed joint can be driven independently while preserving the imported full-body speaking animation.
- **Allowed entries in the in-app Log Tool:**
  - `[INFO]` — one screen-open marker.
  - `[ALINA RIG AUDIT]` — rig readiness plus single-joint probe started/finished/skipped messages.
  - `[ALINA ERROR]` — model missing/load failure only.
- **Everything else is excluded:** routine `[VOICE]` and `[TEXT]`, status/transcript events, mesh/node dumps, layout/gesture debug, scale/framing traces, animation playback chatter, and the already-completed `[ALINA ANIMATION AUDIT]` inventory.
- **Retention and controls:** retain required logs until Clear; preserve Copy All, Copy Selected and Clear.
- **Next user test (one build only):** open Chat Voice while Alina is idle (AI not speaking). The temporary index-49 single-joint probe should rotate one joint by 15° for 0.65s, then restore the saved transforms after 0.85s. If speaking starts during the probe, it is stopped and restored before the imported full-body animation resumes.
- **Evidence to send:** describe whether one localized body segment visibly moves and returns. Send only `[ALINA RIG AUDIT]` lines containing `single-joint probe` started/finished/skipped. The hierarchy audit has already been supplied; do not request or repeat it.
- **Acceptance:** the probe visibly affects only one joint/segment, then returns to the original pose without disturbing normal full-body speaking playback. A compile error or no visible movement is a failed probe, not evidence that the rig is uncontrollable.
- **Do not ask for or collect any other logs in this AN-04 run.**


| 2026-11-11 | AN-04 | Verify visible effect of the index-49 probe while Alina is idle. | User confirmed Alina remained completely still. Device logs showed `single-joint probe started` and `finished; original transforms restored`. Apple documentation distinguishes `.jointTransforms` (skeletal pose) from `.transform` (entity transform). | The probe lifecycle and restore callback ran, but no visible skeletal movement occurred. Inspection found the probe was bound to `.transform`, the wrong target for a `JointTransforms` animation. Corrected only this binding to `.jointTransforms` in `AlinaAvatarView.swift` (commit `98efe5408b5176074e7411029d462b8f6a9e3913`; verified blob `d7159c604b08a20d43b58f56a79daa3df2de8578`). Source-only; no build/device verification yet. | User runs one Codemagic build and repeats the same idle probe. Confirm whether one segment visibly rotates and returns; provide only the existing `[ALINA RIG AUDIT] single-joint probe` lines plus visual result. Do not alter joint index, angle, timing, or unrelated avatar behavior until this test resolves. |


## AN-04 follow-up — full skeletal pose probe
- **Latest device result (2026-11-11):** User confirmed Alina remained motionless both while speaking and while idle; she holds the arms-out imported base pose. Device logs showed the index-49 probe started and finished, but no visible movement. This is a failed visible-control test; lifecycle logs alone do not prove skeletal motion.
- **Diagnosis:** The previous probe set `jointNames` to one name and passed one-element `JointTransforms` values. Although `.jointTransforms` is the correct bind target, use a full skeletal pose for this rig. Apple documents `JointTransforms` as a skeletal pose and its joint-scoped initializer as accepting the joint-name list plus corresponding pose values.
- **Source correction:** Updated `ChatAI/AlinaAvatarView.swift` on `main` (commit `d24a71baeceb44d9f9728e749087a41dc6374dc7`; new blob `e43aadc579af60760764beef3f2f69541e779bc8`). The probe now supplies all 101 runtime joint names and the complete original transform array; the target pose is a copy with only index 49 rotated 15 degrees. It still runs only while the imported clip is paused, then stops and restores the full original transform array. No other avatar behavior changed.
- **Build/test status:** Source-only edit. No build or device test was run by the assistant.
- **Next test:** User runs one Codemagic build and opens Chat Voice with Alina idle. Check whether one localized segment visibly rotates and returns. Send only the visual result and the existing `[ALINA RIG AUDIT]` single-joint probe started/finished lines. Do not request another hierarchy dump or any other logs.


## AN-04 — restore behavior follow-up (2026-11-11)
- **Latest user observation:** The index-49 probe visibly raises Alina's left arm from below to horizontal; the other arm stays still. The left arm remains raised afterward; it does not lower back to the captured pose. This is the first visually confirmed selective-joint movement, but reset acceptance is not met.
- **Source diagnosis:** The probe explicitly used `fillMode = .forwards`, which freezes the final animation frame, and played directly into the entity's base animated value. Apple's RealityKit documentation states `forwards` holds the last frame, while `separateAnimatedValue: true` resets the animated value to its base value when the animation completes. The existing delayed `stop()` can be ineffective after the animation has already completed.
- **Minimal source correction:** Set the probe fill mode to `.none` and play it with `separateAnimatedValue: true`; preserve the same joint index, angle, duration, timing, playback gating, and explicit original-transform restore. Only `ChatAI/AlinaAvatarView.swift` changed. Commit: e5271b7d8a667512e29b6b73161c83e0eeb173f8; blob: 21482d040ff98e580ceec173d0ae3388ac999596. Source-only; no build/device test was run.
- **Next test:** User runs one Codemagic build and checks only whether the left arm rises independently and then returns to its original lowered pose. No new logs are needed unless the existing probe started/finished log is absent.


## AN-04 — startup pose / probe baseline clarification (2026-11-11)
- **User clarification:** Alina's intended original pose is both arms extended horizontally at shoulder height. Do not treat a lowered left arm as the desired reset pose.
- **Observed load sequence:** after loading, the left arm rises and then lowers like the right arm. The prior note describing a lowered pose as the expected original reset target is superseded by this clarification.
- **Source inspection:** on `main`, `attach()` starts the imported `skin0#0` clip with `transitionDuration: 0.25` and `startsPaused: !isSpeaking`, then immediately calls `runSingleJointProbe()`. The probe snapshots `modelEntity.jointTransforms` immediately. Apple documents `transitionDuration` as the fade-in/cross-fade duration and `startsPaused` as pausing animation progress; the documentation does not establish that a paused animation's cross-fade cannot still affect the pose. This makes the startup cross-fade a plausible source of a transient/intermediate baseline, not a proven root cause.
- **Minimal source change:** set the imported clip's transition duration to `0` only when Alina is idle; preserve the existing `0.25s` transition while speaking and preserve paused/resume behavior. This removes the idle cross-fade before the probe captures its baseline. Source commit `3e866648abca644a4132f3845b43fb7da15ddd5d`; verified source blob `73bc71e39f00a3cd3ef55aadd44338c80d64b5cb`.
- **Validation:** source-only. No Codemagic build or device test was run. This change is a targeted test of the cross-fade hypothesis, not confirmation that the pose issue is resolved.
- **Next test:** user runs one build and observes whether the unwanted left-arm raise/lower on load disappears and whether the index-49 probe returns to the two-arms-horizontal pose. No hierarchy dump or extra logs are needed; report only the visible result and existing `[ALINA RIG AUDIT] single-joint probe` started/finished lines if present.

## AN-04 — preserve startup motion and restore bind pose (2026-11-11)
- **User clarification:** the existing build already performs the correct startup arm movement: the left arm raises and lowers like the right. This behavior is accepted; do not ask the user to retest it or change its playback timing.
- **Correction to prior experiment:** the previous edit set the idle clip transition to zero based on an unverified cross-fade hypothesis. Reverted to the established 0.25s transition so the known startup animation behavior remains unchanged.
- **Probe baseline issue:** the probe previously captured the joint transforms after starting the imported clip paused. That snapshot could represent the clip-applied pose rather than the asset's original bind pose.
- **Source change:** capture the full 101-joint transform array before starting the imported clip; use that same pre-animation bind pose for the index-49 probe's from-value and explicit reset. Preserve the existing joint index, 15-degree rotation, 0.65s duration, jointTransforms target, fill mode none, separate animated value, pause/resume behavior, and all avatar framing/gestures. Source commit: b7b312fd54ca1e2e8a8dee9c16e02a2d159c9b6f; blob: 6b95afb276175c93dade6694bb6654612b1be10f.
- **Validation:** source-only; fetched the updated main file and verified the pre-animation snapshot, restored 0.25s clip transition, baseline use, and explicit reset. No build was run.
- **Next check:** one focused AN-04 check only: confirm the probe moves one arm independently and then restores both arms to the horizontal shoulder-height pose. Do not retest startup motion or request hierarchy logs.


## AN-04 completion and AN-05 next probe (2026-11-11)
- **AN-04 acceptance confirmed by user:** the index-49 probe moves the left arm independently, then restores both arms to the intended horizontal shoulder-height pose. The startup movement (left arm raises and lowers like the right) also remains intact in the successful build. AN-04 is complete and locked; do not repeat either test.
- **AN-05 first candidate:** index 77 is a mirrored hierarchy candidate corresponding structurally to the confirmed index-49 branch, but it is not yet anatomically identified. Changed only `jointIndex` from 49 to 77 in `ChatAI/AlinaAvatarView.swift`; the full-pose animation, pre-animation baseline, 15° test, 0.65s duration, 0.85s reset, and playback gating remain unchanged.
- **Source verification:** commit `c7c59cd38935bcddb4a118e05e0c10c4d0c6462e`; blob `577e35484e5b953c81d2b8b1b24a58da3dc2ee15`. Fetched `main` after the write and confirmed index 77 is present and index 49 is no longer the active probe target. No build was run by the assistant.
- **Next user check:** one Chat Voice build while Alina is idle. Report only which body segment visibly moves and whether both arms return to horizontal shoulder height. Do not send hierarchy logs or retest startup motion.


## AN-05 test record — bilateral arm controls (2026-11-11)
- **Test:** run the temporary single-joint probe at index 77, then observe reset behavior.
- **Evidence:** explicit user confirmation: the right arm raises and lowers independently; after it lowers, both arms return to the horizontal shoulder-height pose.
- **Conclusion:** index 77 is visually confirmed as the right-arm control candidate. Combined with the completed index-49 left-arm test, bilateral independent arm control and pose restoration are verified. Startup movement remains accepted and was not retested.
- **Next action:** retain both verified arm indices. Use existing hierarchy evidence to identify the next candidate outside the arms; do not infer anatomy from an unverified numeric index.


## AN-05 — consolidated body-joint sweep (2026-11-11)
- **User decision:** stop testing one body part per build; test the remaining body in one consolidated run.
- **Source change:** sequentially sweep all runtime joint indices except 49 and 77 (the two confirmed arm controls). Each joint receives a 15° local-Z rotation for 0.16s; the full pre-animation transform array is restored before the next joint. Steps are spaced 0.22s apart, approximately 22 seconds for 99 joints.
- **Safety:** only runs while idle. If speaking starts, the restore path invalidates the sequence, stops the active probe, restores the baseline, and makes pending steps no-op. Logs are limited to sweep start/finish and resource-generation errors.
- **Validation:** source-only changes on main; no build/device test was run by the assistant. One user-run build should identify which remaining body regions respond and any abnormal deformation.

| 2026-11-11 | AN-05 | Run one consolidated sweep of all joints other than the already-confirmed arm controls. | User's explicit visual confirmation in chat after the one-pass device test. | All visible regions respond: both legs, ankles, both arms, wrists, hands, fingers, chest, neck, head, mouth and eyes. AN-05 accepted and locked; no per-part retests required. | Begin AN-06: define coordinated, intentional body actions; keep idle/background animation deferred until deliberate control passes. |

| 2026-11-11 | AN-06 | Agree first deliberate body-action scope and motion quality. | User approval in chat. | Approved: greeting wave; nod/shake; head tilt; blink/facial expressions; speech-linked mouth movement; coordinated hand/upper-body gestures. Quality constraints: slow, smooth, eased transitions, coordinated joints, no mesh distortion; no idle/background loop yet. | Inspect Chat Voice emotion/transcript state and implement the smallest safe action controller. |
