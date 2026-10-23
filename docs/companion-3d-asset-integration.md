# Companion 3D asset integration

## Current app behavior

The companion stage in `ChatAI/CompanionChatView.swift` now checks the app bundle for:

```
CompanionChibi.usdz
```

It attempts to load that USDZ with SceneKit and scale the imported scene to a consistent height. If the resource is missing or fails to load, the procedural placeholder remains as a fallback. The original `.vrm` file is a source asset and is **not** loaded directly by this implementation.

## Required asset conversion and bundling

Current source uploaded to the repository:

```
ChatAI/Resources/Koban Chibi Base Mesh VRM export.vrm
```

This source still needs to be converted to `CompanionChibi.usdz`. Conversion must be checked for preserved materials, textures, skeleton/skin, and facial blend shapes; USDZ conversion does not guarantee that all VRM features survive.

After conversion:

1. Put `CompanionChibi.usdz` under the app's resource folder.
2. Ensure the USDZ is included in the `ChatAI` app target and packaged in the app bundle (for a manually maintained Xcode project, verify the target's resource/build configuration).
3. Run a Codemagic Release build and test the companion screen on an iPhone.

## Animation limitations

The existing procedural expressions, blinking, breathing, mouth scaling, and touch-region reactions were written for the placeholder's named nodes. The imported model will not automatically inherit those animations. Before wiring real expressions or lip-sync, inspect the converted model's hierarchy, skeleton/joint names, animation clips, and blend-shape support, then implement rig-specific mappings.

Touch currently maps screen regions to head/cheek/body reactions; it is not mesh-based hit testing.

## Verification checklist

- [ ] Convert the uploaded VRM into `CompanionChibi.usdz`.
- [ ] Verify the converted model's materials and textures.
- [ ] Verify skeleton, animation, and facial blend shapes survived conversion.
- [ ] Include USDZ in the ChatAI app bundle.
- [ ] Confirm the app loads the real model rather than the procedural fallback.
- [ ] Map the actual rig and facial blend shapes to emotion and voice states.
- [ ] Test the Codemagic Release build and touch behavior on device.
