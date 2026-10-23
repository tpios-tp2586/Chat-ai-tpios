# Companion 3D asset integration

## Runtime asset contract

The SwiftUI Companion screen attempts to load a RealityKit asset named `CompanionChibi` from the app bundle:

```swift
try? Entity.load(named: "CompanionChibi")
```

Bundle the converted model as:

```
CompanionChibi.usdz
```

Add the USDZ to the **ChatAI app target** and ensure it is included in **Copy Bundle Resources**. A model placed in the repository but not included in the app target will not be available at runtime.

## Source model

Candidate source: [Anime Chibi Base Mesh (Fully Rigged)](https://kobanwanko.gumroad.com/l/ChibiBaseMesh)

The publisher lists Blender, FBX and VRM versions and 52 ARKit facial blendshapes. The source is not itself a RealityKit-ready USDZ file. Convert and inspect it before bundling; confirm that materials, skeleton/skin, and any required facial blend shapes survive conversion.

## Important runtime limitations

- The current screen uses a procedural avatar only when the bundled model cannot load.
- The procedural fallback does not have real anime mesh geometry or facial blend shapes.
- The current arm movement looks for entities named `leftArmPivot`, `rightArmPivot`, `leftLegPivot`, and `rightLegPivot`. A third-party rig is unlikely to use these names, so rig-specific joint mapping is required for skeletal motion.
- ARKit blend-shape names and support must be checked on the converted asset before implementing real lip-sync and expressions.
- Touch reactions currently use screen regions, not mesh ray-cast hit testing.

## Verification checklist

- [ ] `CompanionChibi.usdz` is included in the app target's resources.
- [ ] Model loads in RealityKit without falling back to the procedural avatar.
- [ ] Textures and materials render correctly on an iPhone.
- [ ] Rig hierarchy and animation clips are inspected and mapped.
- [ ] Facial blend shapes are inspected and mapped to voice/expression state.
- [ ] Touch hit-testing is tested against the actual model.
- [ ] Codemagic Release build succeeds and the app is tested on device.
