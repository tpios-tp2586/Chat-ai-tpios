# Chat AI TPios — Project Status

## Chat Voice avatar — Lily (2026-11-09)

### Current implementation
- Chat Voice now uses `LilyAvatarView` and loads `Lily.usdz` from `ChatAI/Resources`.
- Lily USDZ package integrity passed: 11,210,261 bytes.
- USD structure report: 24 meshes, 1 skeleton, 97 joints, skin joint indices/weights, 1 skeletal animation.
- The scene reports time codes 0.0..0.0 and the animation has two transform samples.
- No BlendShape prims or blendShape weight samples were reported.
- Facial animation and skeletal animation playback are intentionally disabled pending on-device validation.
- Lily load success/failure is written to the existing Chat Voice diagnostic log.
- Zoom and rotation gestures are retained.

### Build pipeline
- Codemagic validates `ChatAI/Resources/Lily.usdz` already present in the repository.
- Codemagic no longer downloads or bundles Ara.
- XcodeGen includes `ChatAI/Resources` as app resources.
- Build output remains unsigned IPA only.

### Protected functionality
- Do not modify `LiveVoice.swift`, `ChatViewModel.swift`, or `Services.swift`.
- Preserve audio pipeline, chat history, Text Chat, and Chibi Chat.
- Keep the Chat Voice diagnostic log and copy-log button.

### Next validation
1. Build and install the IPA.
2. Confirm Lily appears with correct materials, eyes, hair, scale, and orientation.
3. Inspect Chat Voice logs for `[LILY] loaded` or `[LILY ERROR]`.
4. Only after visual validation, investigate supported joint animation and facial-expression options. Do not reuse Ara clip indices.
