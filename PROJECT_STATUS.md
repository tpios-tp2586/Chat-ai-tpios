# Chat AI TPios — Project Status

## Chat Voice avatar — Lily (2026-11-09)

### Current implementation
- Chat Voice uses LilyAvatarView and loads Lily.usdz from ChatAI/Resources.
- USDZ package integrity passed: 11,210,261 bytes.
- USD structure report: 24 meshes, 1 skeleton, 97 joints, skin joint indices/weights, 1 skeletal animation.
- Scene time codes are 0.0..0.0; animation has two transform samples; no BlendShape weights were reported.
- Skeletal/facial animation playback remains disabled pending on-device validation.
- Avatar scale now fits the complete model bounds; zoom uses a fresh v2 preference to avoid the old oversized saved zoom.
- Tap Lily to start or end the Gemini Live voice conversation.
- Text composer sends through the selected chat provider; Chat Voice temporarily enables the existing auto-speak callback so AI replies are spoken. The previous global auto-speak setting is restored when leaving Chat Voice.
- Sending a typed message ends an active microphone session first to avoid overlapping audio sessions.
- Existing diagnostic log and copy button are retained.

### Build pipeline
- Codemagic validates ChatAI/Resources/Lily.usdz already present in the repository.
- Codemagic no longer downloads or bundles Ara.
- XcodeGen includes ChatAI/Resources as app resources.
- Build output remains unsigned IPA only.

### Protected functionality
- Do not modify LiveVoice.swift, ChatViewModel.swift, or Services.swift.
- Preserve audio pipeline, chat history, Text Chat, and Chibi Chat.
- Keep the Chat Voice diagnostic log and copy-log button.

### Next validation
1. Build and install the IPA.
2. Confirm full Lily model framing and tap-to-start/stop voice call.
3. Send a typed message and confirm the selected provider replies through the existing voice output.
4. Confirm the prior Auto Speak setting is restored after leaving Chat Voice.
5. Check diagnostic logs for [LILY], [TEXT], and [VOICE] entries.