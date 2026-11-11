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
| AN-03 | Build a unique-animation catalogue | IN PROGRESS | Catalogue animation definitions across the full entity hierarchy; identify owners, paths, targets, duration, definition types and distinct playable motions. Do not count duplicate wrappers as separate actions. | Existing source already emits `[ALINA ANIMATION INVENTORY]` once per entity/clip, but the current diagnostic filter suppressed those entries. `skin0#0–#20` evidence establishes one sampled motion on `skin0`; #1–#20 duplicate #0 (including the two groups). Source filter first exposed inventory in commit `ce7f5b6a3ff5de7bf4d814c90f2ced464bdeacaf`; it was then narrowed in commit `68c6b54a5836826a1b3a2ca6ed6e061c6515bb2a` to forward only `[ALINA ANIMATION INVENTORY]` lines to the in-app panel. Verbose `[ALINA CLIP DATA]` output is now suppressed. | User runs the next authorized Codemagic/device build and shares only `[ALINA ANIMATION INVENTORY]` lines. Do not resend/retest the `skin0#0–#20` frame data. |
| AN-04 | Visually classify motion semantics | NOT STARTED | Identify which unique motions visibly correspond to idle, listening, thinking, speaking, reacting/emphasis, or determine that the asset lacks a required motion. | Requires a controlled visual test of each unique candidate; names alone are not proof. | Prepare one test matrix after AN-03; do not replay duplicates. |
| AN-05 | Design context-to-animation rules | NOT STARTED | Define state transitions, priority, interruption and return-to-idle behavior; avoid meaningless repeated loops. | Requires AN-04 results. | Agree on the mapping before coding. |
| AN-06 | Implement animation controller | NOT STARTED | Implement only approved mappings using existing assets/APIs; preserve chat, API, history and Gemini Live voice behavior. | No implementation approved yet. | Make minimal source changes after AN-05 approval. |
| AN-07 | Verify integrated animation behavior | NOT STARTED | Confirm each state, transitions, interruption, no unwanted motion at idle, and no regressions to speaking start/stop. | Test only new controller behavior and directly affected paths; prior AL-05 evidence remains valid unless implementation changes that path. | User runs the authorized Codemagic/device test; record results here. |

## Test record
Append a concise entry after each new test. Do not overwrite prior evidence.
| Date | Work ID | Question / test | Evidence reference | Result / conclusion | Next action |
|---|---|---|---|---|---|
| 2026-11-11 | AN-01 | Compare sampled frame data for `skin0#0–#18`. | Chat logs supplied by user in Alina investigation conversation. | All sampled frame data are exact duplicates of #0; not 19 distinct motions. | Locked; no retest. |
| 2026-11-11 | AN-02 | Inspect the children of `skin0#19/#20` and compare sampled joint data with `skin0#0–#18`. | User-supplied device logs in this conversation. | Both groups contain one sampled joint animation child; each child is an exact duplicate of `skin0#0`. AN-02 resolved: these are wrappers, not independent motions. | Locked; proceed to the full hierarchy inventory. |
| 2026-11-11 | AN-03 | Expose only the per-entity animation inventory required to build the unique catalogue. | Source inspection found the inventory logger already implemented. Filter narrowed in source commit `68c6b54a5836826a1b3a2ca6ed6e061c6515bb2a` to forward only `[ALINA ANIMATION INVENTORY]`; verbose `[ALINA CLIP DATA]` entries are suppressed. | Source-only diagnostic routing change; production playback is unchanged. | Await user-run build and collect only `[ALINA ANIMATION INVENTORY]` lines. |
| Previously confirmed | AL-05 | Verify playback at load, while speaking, and after speaking ends. | Three device tests explicitly confirmed by user. | All three behaviors pass. | Locked; no retest unless playback code changes or regression appears. |

## Build and release
- IPA-only output.
- User runs Codemagic. Never trigger builds or GitHub Actions without explicit permission.
- Do not add ZIP artifacts.
