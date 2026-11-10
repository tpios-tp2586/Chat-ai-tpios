# Chat AI TPiOS — Checkpoint

- **Branch:** `main` only. Inspect current source before every edit; no new branches.
- **App:** SwiftUI + XcodeGen (`project.yml`). Codemagic workflow: IPA-only. Never start Codemagic or GitHub Actions without explicit permission.
- **Keep stable:** Text Chat, provider APIs, chat history, Gemini Live voice, Chibi/robot face, settings and theme.
- **Chat Voice:** `CompanionChatView` loads `ChatAI/Resources/Alina.usdz` through `AlinaAvatarView`. Keep the diagnostic log and copy button.
- **Alina framing — LOCKED:** User confirmed full body is now visible with no clipping. Do not alter fitted model height (`targetHeight = 3.20`), fit scale calculation, anchor framing formula, upward adjustment (`targetHeight * 0.20`), depth (`z = -2.8`), zoom pivot, or persisted framing offsets unless the user explicitly asks.
- **Alina rotation — LOCKED:** User confirmed rotation is working well. Preserve the current horizontal drag rotation gesture and sensitivity (`0.01`); do not change it while working on movement.
- **Alina movement:** Hold for 0.30s, then drag. Current implementation uses a native `UILongPressGestureRecognizer` and updates the RealityKit anchor directly during the gesture; persist offsets only when the gesture ends. Test on device for smoothness before further changes.
- **Alina animation research:** Current code inventories `skin0.availableAnimations` (clip name, duration, bind target, blend layer, speed, delay, repeat mode) and currently tests clip index 0 as a loop while AI speaks. Do not assume clip names or semantic actions. First classify every clip from actual inventory and visual playback, identify affected joints/body regions, transition behavior, and safe combinations; then map conversation context to a small action state machine. Do not modify animation playback until the inventory is reviewed.
- **Alina scope:** Full-body skeletal/body animation first; facial rig and lip-sync are not required yet. Keep chatbot, API, chat history, and voice pipeline unchanged.
- **Build/output:** IPA-only. User runs Codemagic; never trigger a build without permission.
- **Engineering:** Minimal changes, no unnecessary dependencies, no changes to Chibi or unrelated chat/voice paths.
