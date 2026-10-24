# ChatAI Companion robot face

The Companion face is drawn with native SwiftUI shapes in `ChatAI/CompanionChatView.swift`. It does not require the Koban VRM model, SceneKit, or an external image asset.

The face shell, pink trim, visor, cyan eyes, highlights, cheeks, mouth, antennae, ears, and side fins are vector shapes rendered by the app. Expressions are driven by the existing Companion state and Gemini Live speaking state.

## Build notes

- Keep the Companion implementation in `ChatAI/CompanionChatView.swift`.
- Keep the existing chat and Gemini Live voice pipeline unchanged.
- Do not add the Koban VRM or USDZ model back to the app bundle unless the design is intentionally migrated back to a 3D model.
- Validate visual proportions on an actual iPhone after each Codemagic build; a successful compile alone does not guarantee visual parity with the reference design.
