# Chat AI TPiOS — Checkpoint

- **Branch:** `main` only. Inspect current source before every edit; no new branches.
- **App:** SwiftUI + XcodeGen (`project.yml`). Codemagic workflow: `ios-unsigned`, IPA-only; unsigned IPA may need signing before iPhone installation.
- **Keep stable:** Text Chat, provider APIs, chat history, Gemini Live voice, Chibi/robot face, settings and theme.
- **Chat Voice:** `CompanionChatView` loads `ChatAI/Resources/Alina.usdz` through `AlinaAvatarView`. Diagnostic log and copy button stay.
- **Alina goal:** Full-body display and later skeletal animation testing; facial rig/lip-sync is not required. Animation playback is disabled until clips are verified.
- **Current framing:** fitted height 1.45; body midpoint centered; zoom pivot and rotation gestures retained. User reports the latest framing build still looks unchanged, so do not keep guessing scale/camera values.
- **Next:** Diagnose the actual ARView viewport, camera projection and model bounds before another framing edit. Compare with a fresh screenshot/log if needed.
- **Build rule:** Never start Codemagic or GitHub Actions without explicit permission. Preserve IPA-only output.
- **Scope rule:** Minimal changes; no extra dependencies; do not modify Chibi or stable chat/voice paths.
