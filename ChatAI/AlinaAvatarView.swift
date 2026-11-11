import Combine
import RealityKit
import SwiftUI
import UIKit

struct AlinaAvatarView: View {
    let isSpeaking: Bool
    let greetingRequest: Int
    let axisTestRequest: (Int, SIMD3<Float>, Float) // joint, axis, angle
    let onLog: (String) -> Void
    let onTap: () -> Void

    @StateObject private var loader = AlinaAvatarLoader()
    @AppStorage("alina_avatar_zoom_scale_v1") private var savedZoomScale = 2.5
    @AppStorage("alina_avatar_position_x_v1") private var savedOffsetX = 0.0
    @AppStorage("alina_avatar_position_y_v1") private var savedOffsetY = 0.0
    @State private var pinchStartScale = 1.0
    @State private var isMovingAvatar = false
    @State private var rotationY: Float = 0
    @State private var dragStartRotation: Float = 0

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { savedZoomScale = min(max(pinchStartScale * Double($0), 0.7), 4.5) }
            .onEnded { _ in pinchStartScale = savedZoomScale }
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isMovingAvatar,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                rotationY = dragStartRotation + Float(value.translation.width) * 0.01
            }
            .onEnded { _ in
                dragStartRotation = rotationY
            }
    }

    var body: some View {
        ZStack {
            if let entity = loader.entity {
                AlinaRealityView(
                    entity: entity,
                    isSpeaking: isSpeaking,
                    greetingRequest: greetingRequest,
                    axisTestRequest: axisTestRequest,
                    zoomScale: Float(savedZoomScale),
                    rotationY: rotationY,
                    offsetX: Float(savedOffsetX),
                    offsetY: Float(savedOffsetY),
                    onLog: onLog,
                    onMoveStarted: { isMovingAvatar = true },
                    onMoveEnded: { x, y in
                        savedOffsetX = Double(x)
                        savedOffsetY = Double(y)
                        isMovingAvatar = false
                    }
                )
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(loader.status)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding()
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(rotationGesture)
        .simultaneousGesture(TapGesture().onEnded { onTap() })
        .task {
            pinchStartScale = savedZoomScale
            loader.onLog = onLog
            loader.load()
        }
    }
}

@MainActor
private final class AlinaAvatarLoader: ObservableObject {
    @Published var entity: Entity?
    @Published var status = "Đang nạp Alina…"
    var onLog: ((String) -> Void)?
    private var loaded = false

    func load() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "Alina", withExtension: "usdz") else {
            status = "Không tìm thấy Alina.usdz"
            onLog?("[ALINA ERROR] Alina.usdz missing from app bundle")
            return
        }

        onLog?("[ALINA] loading Alina.usdz")
        Task { @MainActor in
            do {
                let model = try await Entity.load(contentsOf: url)
                var animationCount = 0
                func collect(_ node: Entity) {
                    animationCount += node.availableAnimations.count
                    for child in node.children {
                        collect(child)
                    }
                }
                collect(model)
                model.stopAllAnimations()
                entity = model
                status = "Alina đã sẵn sàng"
                onLog?("[ALINA] loaded; animations=\(animationCount) across hierarchy; inventory=per entity; playback test=skin0 clip 0 (after attach)")
                onLog?("[ALINA DEBUG] publishing root entity; name=\(model.name), children=\(model.children.count), enabled=\(model.isEnabled)")
            } catch {
                status = "Lỗi nạp Alina: \(error.localizedDescription)"
                onLog?("[ALINA ERROR] load failed: \(error)")
            }
        }
    }
}

private struct AlinaRealityView: UIViewRepresentable {
    let entity: Entity
    let isSpeaking: Bool
    let greetingRequest: Int
    let axisTestRequest: (Int, SIMD3<Float>, Float)
    let zoomScale: Float
    let rotationY: Float
    let offsetX: Float
    let offsetY: Float
    let onLog: (String) -> Void
    let onMoveStarted: () -> Void
    let onMoveEnded: (Float, Float) -> Void

    func makeUIView(context: Context) -> ARView {
        logDeferred("[ALINA DEBUG] makeUIView entered")
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, isSpeaking: isSpeaking, greetingRequest: greetingRequest, zoomScale: zoomScale, rotationY: rotationY, offsetX: offsetX, offsetY: offsetY, to: view, coordinator: context.coordinator)
        context.coordinator.installMoveGesture(
            on: view,
            onStarted: onMoveStarted,
            onEnded: onMoveEnded
        )
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        if !context.coordinator.didLogUpdate {
            logDeferred("[ALINA DEBUG] updateUIView entered; bounds=\(view.bounds.size)")
            context.coordinator.didLogUpdate = true
        }
        if !context.coordinator.didLogLayout, view.bounds.width > 0, view.bounds.height > 0 {
            logDeferred("[ALINA DEBUG] ARView layout size=\(view.bounds.size)")
            context.coordinator.didLogLayout = true
        }
        if context.coordinator.currentEntity !== entity {
            attach(entity, isSpeaking: isSpeaking, greetingRequest: greetingRequest, zoomScale: zoomScale, rotationY: rotationY, offsetX: offsetX, offsetY: offsetY, to: view, coordinator: context.coordinator)
        } else {
            if context.coordinator.lastIsSpeaking != isSpeaking {
                context.coordinator.lastIsSpeaking = isSpeaking
                if isSpeaking {
                    restoreGreetingWave(coordinator: context.coordinator)
                    if let rig = context.coordinator.rigEntity {
                        runSpeechGesture(on: rig, baselineTransforms: context.coordinator.bindPoseTransforms, coordinator: context.coordinator)
                    }
                } else {
                    restoreSpeechGesture(coordinator: context.coordinator)
                }
            }
            if greetingRequest != context.coordinator.lastGreetingRequest {
                context.coordinator.lastGreetingRequest = greetingRequest
                if !isSpeaking, let rig = context.coordinator.rigEntity {
                    runGreetingWave(on: rig, baselineTransforms: context.coordinator.bindPoseTransforms, coordinator: context.coordinator)
                }
            }
            if context.coordinator.currentZoom != zoomScale {
                applyZoom(zoomScale, coordinator: context.coordinator)
            }
            if context.coordinator.currentRotationY != rotationY {
                applyRotation(rotationY, coordinator: context.coordinator)
            }
            if context.coordinator.currentOffsetX != offsetX || context.coordinator.currentOffsetY != offsetY {
                applyPosition(offsetX: offsetX, offsetY: offsetY, coordinator: context.coordinator)
            }
            if axisTestRequest.0 >= 0 {
                runAxisTest(jointIndex: axisTestRequest.0, axis: axisTestRequest.1, angle: axisTestRequest.2, coordinator: context.coordinator)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func logDeferred(_ message: String) {
        // Keep only the one-pass animation audit and actionable playback/load diagnostics.
        guard message.hasPrefix("[ALINA RIG AUDIT]") ||
              message.hasPrefix("[ALINA ERROR]") else { return }
        let callback = onLog
        DispatchQueue.main.async {
            callback(message)
        }
    }

    private func attach(
        _ model: Entity,
        isSpeaking: Bool,
        greetingRequest: Int,
        zoomScale: Float,
        rotationY: Float,
        offsetX: Float,
        offsetY: Float,
        to view: ARView,
        coordinator: Coordinator
    ) {
        logDeferred("[ALINA DEBUG] attach entered; original root position=\(model.position), scale=\(model.scale), children=\(model.children.count), enabled=\(model.isEnabled)")
        var inspectedNodes = 0
        var meshNodes = 0
        var originallyDisabledNodes = 0

        func inspectHierarchy(_ node: Entity, path: String, depth: Int) {
            guard inspectedNodes < 180 else { return }
            inspectedNodes += 1
            let wasEnabled = node.isEnabled
            if !wasEnabled { originallyDisabledNodes += 1 }

            if node.components[ModelComponent.self] != nil {
                meshNodes += 1
                let localBounds = node.visualBounds(recursive: false, relativeTo: model)
                let worldBounds = node.visualBounds(recursive: false, relativeTo: nil)
                logDeferred("[ALINA MESH] path=\(path), name=\(node.name), enabledBeforeForce=\(wasEnabled), position=\(node.position), scale=\(node.scale), localCenter=\(localBounds.center), localExtents=\(localBounds.extents), worldCenter=\(worldBounds.center), worldExtents=\(worldBounds.extents)")
            } else if depth <= 2 {
                logDeferred("[ALINA NODE] path=\(path), name=\(node.name), enabledBeforeForce=\(wasEnabled), position=\(node.position), scale=\(node.scale), children=\(node.children.count)")
            }

            for (index, child) in node.children.enumerated() {
                inspectHierarchy(child, path: "\(path)/\(index)", depth: depth + 1)
            }
        }

        inspectHierarchy(model, path: "root", depth: 0)
        logDeferred("[ALINA DEBUG] imported hierarchy: inspectedNodes=\(inspectedNodes), meshNodes=\(meshNodes), originallyDisabledNodes=\(originallyDisabledNodes), rootChildren=\(model.children.count)")

        func enableAll(_ node: Entity) {
            node.isEnabled = true
            for child in node.children { enableAll(child) }
        }
        enableAll(model)
        logDeferred("[ALINA DEBUG] hierarchy enabled after inspection")

        let worldBounds = model.visualBounds(recursive: true, relativeTo: nil)
        let localBounds = model.visualBounds(recursive: true, relativeTo: model)
        logDeferred("[ALINA DEBUG] pre-fit world bounds center=\(worldBounds.center), extents=\(worldBounds.extents)")
        logDeferred("[ALINA DEBUG] pre-fit local bounds center=\(localBounds.center), extents=\(localBounds.extents)")

        // Slightly enlarge the fitted body while keeping the feet at Y=0.
        let height = localBounds.extents.y
        let targetHeight: Float = 3.20
        let baseScale: Float = (height.isFinite && height > 0.01) ? targetHeight / height : 1.0
        // After scaling: model bottom = localBounds.min.y * baseScale (negative), top = localBounds.max.y * baseScale
        // Shift model up so feet (min Y) sit at Y=0 relative to anchor
        let minY = localBounds.min.y * baseScale
        let modelOffsetY: Float = -minY  // moves feet to 0
        // Center horizontally
        let modelOffsetX: Float = -localBounds.center.x * baseScale
        let modelOffsetZ: Float = -localBounds.center.z * baseScale

        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        coordinator.basePosition = SIMD3<Float>(modelOffsetX, modelOffsetY, modelOffsetZ)
        coordinator.currentEntity = model
        coordinator.lastIsSpeaking = isSpeaking

        // Put the model's midpoint at the viewport center; do not add an upward offset.
        let midBodyY = targetHeight / 2.0
        // Move the unchanged-size model upward in the viewport so the feet remain visible.
        let baseAnchorY = -midBodyY - targetHeight * 0.50 - 0.10
        let upwardAdjustment = targetHeight * 0.20
        let anchorPosition = SIMD3<Float>(0, baseAnchorY + upwardAdjustment, -2.8)
        let anchor = AnchorEntity(world: anchorPosition)
        coordinator.baseAnchorPosition = anchorPosition
        let zoomPivot = Entity()
        zoomPivot.addChild(model)
        model.position = coordinator.basePosition
        model.scale = coordinator.baseScale
        anchor.addChild(zoomPivot)
        coordinator.rotationPivot = anchor
        coordinator.zoomPivot = zoomPivot
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)

        if let skin = findEntity(named: "skin0", in: model) {
            let modelEntity = skin as? ModelEntity
            coordinator.rigEntity = modelEntity
            coordinator.bindPoseTransforms = modelEntity?.jointTransforms
            logDeferred("[ALINA RIG AUDIT] verified bind pose captured; imported TempMotion playback disabled")
            if isSpeaking, let rig = coordinator.rigEntity {
                runSpeechGesture(on: rig, baselineTransforms: coordinator.bindPoseTransforms, coordinator: coordinator)
            }
        } else {
            logDeferred("[ALINA RIG AUDIT] skin0 entity not found; gesture control unavailable")
        }


        if greetingRequest != coordinator.lastGreetingRequest {
            coordinator.lastGreetingRequest = greetingRequest
            if !isSpeaking, let rig = coordinator.rigEntity {
                runGreetingWave(on: rig, baselineTransforms: coordinator.bindPoseTransforms, coordinator: coordinator)
            }
        }

        applyZoom(zoomScale, coordinator: coordinator)
        applyRotation(rotationY, coordinator: coordinator)
        applyPosition(offsetX: offsetX, offsetY: offsetY, coordinator: coordinator)
        logDeferred("[ALINA SCALE] height=\(height) baseScale=\(baseScale) offsetY=\(modelOffsetY)")
    }

    private func runGreetingWave(on modelEntity: ModelEntity, baselineTransforms: [Transform]?, coordinator: Coordinator) {
        guard !coordinator.lastIsSpeaking,
              let originalTransforms = baselineTransforms,
              originalTransforms.count == modelEntity.jointNames.count,
              modelEntity.jointNames.indices.contains(77) else {
            logDeferred("[ALINA RIG AUDIT] greeting wave skipped; rig baseline or verified arm joint unavailable")
            return
        }

        restoreGreetingWave(coordinator: coordinator)
        var targetTransforms = originalTransforms
        let lift = simd_quatf(angle: .pi / 12, axis: SIMD3<Float>(0, 0, 1))
        targetTransforms[77].rotation = simd_normalize(originalTransforms[77].rotation * lift)

        var definition = FromToByAnimation<JointTransforms>()
        definition.name = "AlinaGreetingWave"
        definition.jointNames = modelEntity.jointNames
        definition.isScaleAnimated = false
        definition.isTranslationAnimated = false
        definition.isRotationAnimated = true
        definition.fromValue = JointTransforms(originalTransforms)
        definition.toValue = JointTransforms(targetTransforms)
        definition.duration = 0.75
        definition.timing = .easeInOut
        definition.repeatMode = .autoReverse
        definition.blendLayer = 100
        definition.fillMode = .none
        definition.bindTarget = .jointTransforms

        guard let resource = try? AnimationResource.generate(with: definition) else {
            logDeferred("[ALINA RIG AUDIT] greeting wave resource generation failed")
            return
        }

        coordinator.greetingWaveSequenceID += 1
        let sequenceID = coordinator.greetingWaveSequenceID
        coordinator.greetingWaveEntity = modelEntity
        coordinator.greetingWaveOriginalTransforms = originalTransforms
        coordinator.greetingWaveController = modelEntity.playAnimation(
            resource,
            transitionDuration: 0.12,
            blendLayerOffset: 0,
            separateAnimatedValue: true,
            startsPaused: false
        )
        logDeferred("[ALINA RIG AUDIT] greeting arm motion started; verifiedJoint=77; lift=15deg; easedCycle=0.75s")

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak coordinator] in
            guard let coordinator, coordinator.greetingWaveSequenceID == sequenceID else { return }
            coordinator.greetingWaveController?.stop()
            modelEntity.jointTransforms = originalTransforms
            coordinator.greetingWaveController = nil
            coordinator.greetingWaveEntity = nil
            coordinator.greetingWaveOriginalTransforms = nil
            logDeferred("[ALINA RIG AUDIT] greeting arm motion finished; original pose restored")
        }
    }

    private func restoreGreetingWave(coordinator: Coordinator) {
        coordinator.greetingWaveSequenceID += 1
        coordinator.greetingWaveController?.stop()
        if let entity = coordinator.greetingWaveEntity,
           let transforms = coordinator.greetingWaveOriginalTransforms {
            entity.jointTransforms = transforms
        }
        coordinator.greetingWaveController = nil
        coordinator.greetingWaveEntity = nil
        coordinator.greetingWaveOriginalTransforms = nil
    }

    private func runSpeechGesture(
        on modelEntity: ModelEntity,
        baselineTransforms: [Transform]?,
        coordinator: Coordinator
    ) {
        guard coordinator.lastIsSpeaking,
              let originalTransforms = baselineTransforms,
              originalTransforms.count == modelEntity.jointNames.count,
              modelEntity.jointNames.indices.contains(49),
              modelEntity.jointNames.indices.contains(77) else {
            return
        }

        restoreSpeechGesture(coordinator: coordinator)
        var targetTransforms = originalTransforms
        let lift = simd_quatf(angle: .pi / 30, axis: SIMD3<Float>(0, 0, 1))
        for jointIndex in [49, 77] {
            targetTransforms[jointIndex].rotation = simd_normalize(
                originalTransforms[jointIndex].rotation * lift
            )
        }

        var definition = FromToByAnimation<JointTransforms>()
        definition.name = "AlinaSpeechGesture"
        definition.jointNames = modelEntity.jointNames
        definition.isScaleAnimated = false
        definition.isTranslationAnimated = false
        definition.isRotationAnimated = true
        definition.fromValue = JointTransforms(originalTransforms)
        definition.toValue = JointTransforms(targetTransforms)
        definition.duration = 2.0
        definition.timing = .easeInOut
        definition.repeatMode = .autoReverse
        definition.blendLayer = 110
        definition.fillMode = .none
        definition.bindTarget = .jointTransforms

        guard let resource = try? AnimationResource.generate(with: definition) else {
            logDeferred("[ALINA RIG AUDIT] speech gesture resource generation failed")
            return
        }

        coordinator.speechGestureEntity = modelEntity
        coordinator.speechGestureOriginalTransforms = originalTransforms
        coordinator.speechGestureController = modelEntity.playAnimation(
            resource,
            transitionDuration: 0.25,
            blendLayerOffset: 0,
            separateAnimatedValue: true,
            startsPaused: false
        )
        logDeferred("[ALINA RIG AUDIT] coordinated speech gesture loop started; verifiedArmJoints=49,77; angle=6deg; halfCycle=2.0s")
    }

    private func restoreSpeechGesture(coordinator: Coordinator) {
        coordinator.speechGestureController?.stop()
        if let entity = coordinator.speechGestureEntity,
           let transforms = coordinator.speechGestureOriginalTransforms {
            entity.jointTransforms = transforms
        }
        coordinator.speechGestureController = nil
        coordinator.speechGestureEntity = nil
        coordinator.speechGestureOriginalTransforms = nil
    }

    private func logAnimationInventory(in root: Entity) {
        var ownerSummaries: [String] = []
        var clipSummaries: [String] = []
        var uniqueSamples: [(label: String, frames: [JointTransforms], jointNames: [String], frameInterval: Float)] = []
        var totalEntityReferences = 0
        var uniqueDefinitionCount = 0
        var duplicateSampleCount = 0
        var emptyGroupCount = 0
        var nonEmptyGroupCount = 0
        var unsupportedCount = 0

        func recordSample(_ sample: SampledAnimation<JointTransforms>, label: String, duration: TimeInterval, target: String) {
            let frames = sample.frames
            let jointNames = sample.jointNames
            if let duplicate = uniqueSamples.first(where: {
                $0.frames == frames &&
                $0.jointNames == jointNames &&
                $0.frameInterval == sample.frameInterval
            }) {
                duplicateSampleCount += 1
                clipSummaries.append("\(label):DUPLICATE_OF=\(duplicate.label);duration=\(duration);frames=\(frames.count);joints=\(jointNames.count)")
                return
            }

            var movingJointNames: [String] = []
            if let firstFrame = frames.first, frames.count > 1 {
                for jointIndex in 0..<min(jointNames.count, firstFrame.count) {
                    let initial = firstFrame[jointIndex]
                    var maxTranslation: Float = 0
                    var maxRotation: Float = 0
                    for frame in frames.dropFirst() where jointIndex < frame.count {
                        let transform = frame[jointIndex]
                        maxTranslation = max(maxTranslation, simd_length(transform.translation - initial.translation))
                        let dot = min(max(abs(simd_dot(initial.rotation, transform.rotation)), 0), 1)
                        maxRotation = max(maxRotation, 2 * acos(dot))
                    }
                    if maxTranslation > 0.0001 || maxRotation > 0.001 {
                        movingJointNames.append(jointNames[jointIndex])
                    }
                }
            }

            uniqueDefinitionCount += 1
            uniqueSamples.append((label, frames, jointNames, sample.frameInterval))
            let examples = movingJointNames.prefix(8).joined(separator: ",")
            clipSummaries.append("\(label):UNIQUE_SAMPLED;duration=\(duration);target=\(target);frames=\(frames.count);joints=\(jointNames.count);interval=\(sample.frameInterval);movingJoints=\(movingJointNames.count);examples=\(examples)")
        }

        func inspectGroup(_ group: AnimationGroup, label: String, depth: Int) {
            if group.group.isEmpty {
                emptyGroupCount += 1
                clipSummaries.append("\(label):EMPTY_GROUP;duration=\(group.duration);target=\(String(reflecting: group.bindTarget))")
                return
            }
            nonEmptyGroupCount += 1
            clipSummaries.append("\(label):GROUP;name=\(group.name);children=\(group.group.count);duration=\(group.duration);target=\(String(reflecting: group.bindTarget))")
            guard depth < 6 else {
                unsupportedCount += group.group.count
                clipSummaries.append("\(label):MAX_GROUP_DEPTH_REACHED")
                return
            }
            for (childIndex, child) in group.group.enumerated() {
                let childLabel = "\(label).child#\(childIndex)"
                if let sampled = child as? SampledAnimation<JointTransforms> {
                    recordSample(sampled, label: childLabel, duration: child.duration, target: String(reflecting: child.bindTarget))
                } else if let nested = child as? AnimationGroup {
                    inspectGroup(nested, label: childLabel, depth: depth + 1)
                } else {
                    unsupportedCount += 1
                    clipSummaries.append("\(childLabel):UNSUPPORTED;type=\(String(reflecting: type(of: child)));duration=\(child.duration);target=\(String(reflecting: child.bindTarget))")
                }
            }
        }

        func visit(_ node: Entity, path: String) {
            let animations = node.availableAnimations
            if !animations.isEmpty {
                totalEntityReferences += animations.count
                var signatures = Set<String>()
                for (index, animation) in animations.enumerated() {
                    let definition = animation.definition
                    signatures.insert("\(animation.name ?? "unnamed")|\(definition.duration)|\(String(reflecting: definition.bindTarget))|\(String(reflecting: type(of: definition)))|layer=\(definition.blendLayer)|speed=\(definition.speed)|delay=\(definition.delay)|repeat=\(String(reflecting: definition.repeatMode))")
                    let label = "\(path)#\(index)"
                    if let sampled = definition as? SampledAnimation<JointTransforms> {
                        recordSample(sampled, label: label, duration: definition.duration, target: String(reflecting: definition.bindTarget))
                    } else if let group = definition as? AnimationGroup {
                        inspectGroup(group, label: label, depth: 0)
                    } else {
                        unsupportedCount += 1
                        clipSummaries.append("\(label):UNSUPPORTED_DEFINITION;type=\(String(reflecting: type(of: definition)));duration=\(definition.duration);target=\(String(reflecting: definition.bindTarget))")
                    }
                }
                ownerSummaries.append("\(path){refs=\(animations.count);uniqueMetadata=\(signatures.count)}")
            }

            for (index, child) in node.children.enumerated() {
                visit(child, path: "\(path)/\(index):\(child.name)")
            }
        }

        visit(root, path: "root:\(root.name)")
        logDeferred("[ALINA ANIMATION AUDIT] totals entityReferences=\(totalEntityReferences);uniqueSampled=\(uniqueDefinitionCount);duplicateSampled=\(duplicateSampleCount);nonEmptyGroups=\(nonEmptyGroupCount);emptyGroups=\(emptyGroupCount);unsupported=\(unsupportedCount)")
        for start in stride(from: 0, to: ownerSummaries.count, by: 3) {
            let end = min(start + 3, ownerSummaries.count)
            logDeferred("[ALINA ANIMATION AUDIT] owners \(start + 1)-\(end): \(ownerSummaries[start..<end].joined(separator: " | "))")
        }
        for start in stride(from: 0, to: clipSummaries.count, by: 4) {
            let end = min(start + 4, clipSummaries.count)
            logDeferred("[ALINA ANIMATION AUDIT] clips \(start + 1)-\(end): \(clipSummaries[start..<end].joined(separator: " | "))")
        }
    }

    func runAxisTest(jointIndex: Int, axis: SIMD3<Float>, angle: Float, coordinator: Coordinator) {
        guard let rig = coordinator.rigEntity,
              let baseline = coordinator.bindPoseTransforms,
              jointIndex < baseline.count else {
            onLog("[ALINA RIG AUDIT] axis test skipped: rig not ready")
            return
        }
        // Stop any existing speech gesture
        coordinator.speechGestureController?.stop()
        coordinator.speechGestureEntity = nil

        var target = baseline
        let q = simd_quatf(angle: angle * .pi / 180, axis: simd_normalize(axis))
        target[jointIndex].rotation = simd_normalize(baseline[jointIndex].rotation * q)

        var def = FromToByAnimation<JointTransforms>()
        def.jointNames = rig.jointNames
        def.isScaleAnimated = false
        def.isTranslationAnimated = false
        def.isRotationAnimated = true
        def.fromValue = JointTransforms(baseline)
        def.toValue = JointTransforms(target)
        def.duration = 0.8
        def.timing = .easeInOut
        def.repeatMode = .autoReverse
        def.blendLayer = 120
        def.fillMode = .none
        def.bindTarget = .jointTransforms

        guard let resource = try? AnimationResource.generate(with: def) else {
            onLog("[ALINA RIG AUDIT] axis test resource failed")
            return
        }
        coordinator.speechGestureEntity = rig
        coordinator.speechGestureOriginalTransforms = baseline
        coordinator.speechGestureController = rig.playAnimation(
            resource, transitionDuration: 0.1,
            blendLayerOffset: 0, separateAnimatedValue: true, startsPaused: false
        )
        onLog("[ALINA RIG AUDIT] axis test: joint=\(jointIndex) axis=(\(axis.x),\(axis.y),\(axis.z)) angle=\(angle)deg")

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak coordinator] in
            coordinator?.speechGestureController?.stop()
            rig.jointTransforms = baseline
            coordinator?.speechGestureController = nil
            coordinator?.speechGestureEntity = nil
        }
    }

        private func findEntity(named name: String, in root: Entity) -> Entity? {
        if root.name == name { return root }
        for child in root.children {
            if let match = findEntity(named: name, in: child) { return match }
        }
        return nil
    }

    private func applyZoom(_ zoom: Float, coordinator: Coordinator) {
        coordinator.zoomPivot?.scale = SIMD3<Float>(repeating: zoom)
        coordinator.currentZoom = zoom
    }

    private func applyRotation(_ rotation: Float, coordinator: Coordinator) {
        guard let pivot = coordinator.rotationPivot else { return }
        pivot.orientation = simd_quatf(angle: rotation, axis: SIMD3<Float>(0, 1, 0))
        coordinator.currentRotationY = rotation
    }

    private func applyPosition(offsetX: Float, offsetY: Float, coordinator: Coordinator) {
        guard let anchor = coordinator.rotationPivot else { return }
        anchor.position = coordinator.baseAnchorPosition + SIMD3<Float>(offsetX, offsetY, 0)
        coordinator.currentOffsetX = offsetX
        coordinator.currentOffsetY = offsetY
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var currentEntity: Entity?
        var greetingWaveController: AnimationPlaybackController?
        weak var greetingWaveEntity: ModelEntity?
        var greetingWaveOriginalTransforms: [Transform]?
        var greetingWaveSequenceID = 0
        var speechGestureController: AnimationPlaybackController?
        weak var speechGestureEntity: ModelEntity?
        var speechGestureOriginalTransforms: [Transform]?
        weak var rigEntity: ModelEntity?
        var bindPoseTransforms: [Transform]?
        var lastGreetingRequest = 0
        var lastIsSpeaking = false
        var rotationPivot: AnchorEntity?
        var zoomPivot: Entity?
        var baseScale = SIMD3<Float>(repeating: 1)
        var basePosition = SIMD3<Float>(repeating: 0)
        var baseAnchorPosition = SIMD3<Float>(repeating: 0)
        var currentZoom: Float = 1
        var currentRotationY: Float = 0
        var currentOffsetX: Float = 0
        var currentOffsetY: Float = 0
        var didLogLayout = false
        var didLogUpdate = false
        private var moveStartPoint: CGPoint?
        private var moveStartAnchorPosition: SIMD3<Float>?
        private var onMoveStarted: (() -> Void)?
        private var onMoveEnded: ((Float, Float) -> Void)?

        func installMoveGesture(
            on view: ARView,
            onStarted: @escaping () -> Void,
            onEnded: @escaping (Float, Float) -> Void
        ) {
            onMoveStarted = onStarted
            onMoveEnded = onEnded
            let gesture = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleMoveGesture(_:))
            )
            gesture.minimumPressDuration = 0.30
            gesture.allowableMovement = 1000
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            view.addGestureRecognizer(gesture)
        }

        @objc private func handleMoveGesture(_ gesture: UILongPressGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .began:
                guard let anchor = rotationPivot else { return }
                moveStartPoint = gesture.location(in: view)
                moveStartAnchorPosition = anchor.position
                onMoveStarted?()
            case .changed:
                guard let anchor = rotationPivot,
                      let startPoint = moveStartPoint,
                      let startPosition = moveStartAnchorPosition else { return }
                let point = gesture.location(in: view)
                let dx = Float(point.x - startPoint.x) * 0.005
                let dy = Float(point.y - startPoint.y) * -0.005
                anchor.position = startPosition + SIMD3<Float>(dx, dy, 0)
            case .ended:
                finishMove(commit: true)
            case .cancelled, .failed:
                finishMove(commit: false)
            default:
                break
            }
        }

        private func finishMove(commit: Bool) {
            guard let anchor = rotationPivot,
                  let startPosition = moveStartAnchorPosition else {
                onMoveEnded?(currentOffsetX, currentOffsetY)
                return
            }
            if !commit {
                anchor.position = startPosition
            }
            let offset = anchor.position - baseAnchorPosition
            currentOffsetX = offset.x
            currentOffsetY = offset.y
            onMoveEnded?(currentOffsetX, currentOffsetY)
            moveStartPoint = nil
            moveStartAnchorPosition = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}