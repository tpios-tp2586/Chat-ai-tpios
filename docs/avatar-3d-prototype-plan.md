# ChatAI 3D Avatar Prototype Plan

## Safety boundary
- Work only on branch `avatar-3d-prototype`.
- Do not edit chat, API, history, or voice-session logic.
- Keep `CompanionChatView.swift` unchanged until the isolated avatar component is validated.
- No merge to `main` without a successful build and visual review.

## Current findings
- `ChatAI/CompanionChatView.swift` currently renders `ApprovedRobotHead` in SwiftUI.
- The mouth animation toggles while `isSpeaking`; this is not phoneme- or audio-amplitude-driven lip sync.
- The referenced `face-to-blendshape-3d` project generates a face mesh from MediaPipe landmarks and advertises GLB export with ARKit-named morph targets.
- Its generator creates 42 morph target names in `MORPH_TARGET_NAMES`, not 52. The current `jawOpen` target moves every vertex with negative Y, which is a crude deformation rather than a proper lower-jaw/lip rig.
- A 478-landmark face surface is not a complete head with modeled eyes, hair, ears, and a back of head. Do not treat it as a finished avatar asset without inspection.

## Minimal implementation sequence
1. Obtain and validate the reference portrait the user selected; do not substitute a different face without approval.
2. Produce or select a complete head asset (GLB/USDZ) with visible eyes and hair. Confirm it renders from front and side.
3. Verify the asset has usable mouth morph targets (at minimum jawOpen plus mouth shapes) and that changing the weights visibly moves the lips/jaw.
4. Implement a standalone `ChatAIHead3DView` prototype in a separate file/branch. Keep the existing SwiftUI robot available as a fallback.
5. Connect only the avatar's mouth parameter to the existing speaking/audio signal in a later step; avoid changing voice transport or chatbot behavior.
6. Build the iOS target and inspect visual output before proposing a merge.

## Acceptance criteria
- Chat and voice session behavior is unchanged.
- Avatar is a full head, not a flat face patch.
- Eyes, hair, skin texture, and head silhouette look coherent from front and three-quarter views.
- Mouth visibly opens and closes with a controllable blendshape, without stretching the entire lower half of the face.
- Build succeeds on the existing ChatAI scheme.
