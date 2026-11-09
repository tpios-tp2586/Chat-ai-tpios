# Chat AI TPios — Project Status

## Chat Voice avatar — Lily (2026-11-09)

### Current implementation
- Chat Voice uses LilyAvatarView and loads Lily.usdz from ChatAI/Resources.
- USDZ package integrity passed: 11,210,261 bytes.
- USD structure report: 24 meshes, 1 skeleton, 97 joints, skin joint indices/weights, 1 skeletal animation.
- Scene time codes are 0.0..0.0; animation has two transform samples; no BlendShape weights were reported.
- Skeletal/facial animation playback remains disabled pending on-device validation.
- Avatar scale target reduced from 1.45 to 0.55 world units; zoom uses a fresh v3 preference so earlier saved zoom values cannot override the new default. Runtime logs include measured bounds and applied scale.
- Tap Lily to start or end the Gemini Live voice conversation.
- Text composer sends through the selected chat provider. Chat Voice explicitly injects the existing VoiceManager TTS callback, enables auto-speak for typed replies, and restores the previous callback and setting when leaving.
- Sending a typed message always tears down the Gemini Live session before provider chat; the reply is routed to VoiceManager TTS, not the Gemini Live audio stream. Diagnostic log records the selected provider and TTS callback invocation.
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
3. Send a typed message and confirm the selected provider replies through VoiceManager TTS (Azure when configured, otherwise iOS Vietnamese speech fallback); logs should show [TEXT] and [TTS].
4. Confirm the prior Auto Speak setting is restored after leaving Chat Voice.
5. Check diagnostic logs for [LILY], [TEXT], and [VOICE] entries.