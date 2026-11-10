import Combine
import RealityKit
import SwiftUI

struct AlinaAvatarView: View {
    let isSpeaking: Bool
    let onLog: (String) -> Void
    let onTap: () -> Void

    @StateObject private var loader = AlinaAvatarLoader()
    @AppStorage("alina_avatar_zoom_scale_v1") private var savedZoomScale = 2.5
    @State private var pinchStartScale = 1.0
    @State private var rotationY: Float = 0
    @State private var dragStartRotation: Float = 0

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { savedZoomScale = min(max(pinchStartScale * Double($0), 0.7), 4.5) }
            .onEnded { _ in pinchStartScale = savedZoomScale }
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { rotationY = dragStartRotation + Float($0.translation.width) * (.pi / 360) }
            .onEnded { _ in dragStartRotation = rotationY }
    }

    var body: some View {
        ZStack {
            if let entity = loader.entity {
                AlinaRealityView(entity: entity, isSpeaking: isSpeaking, zoomScale: Float(savedZoomScale), rotationY: rotationY, onLog: onLog)
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
                onLog?("[ALINA] loaded; animations=\(animationCount); playback test=default subtree animation (after attach)")
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
    let zoomScale: Float
    let rotationY: Float
    let onLog: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        logDeferred("[ALINA DEBUG] makeUIView entered")
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, isSpeaking: isSpeaking, zoomScale: zoomScale, rotationY: rotationY, to: view, coordinator: context.coordinator)
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
            attach(entity, isSpeaking: isSpeaking, zoomScale: zoomScale, rotationY: rotationY, to: view, coordinator: context.coordinator)
        } else {
            if context.coordinator.lastIsSpeaking != isSpeaking {
                if isSpeaking {
                    context.coordinator.animationController?.resume()
                } else {
                    context.coordinator.animationController?.pause()
                }
                context.coordinator.lastIsSpeaking = isSpeaking
            }
            if context.coordinator.currentZoom != zoomScale {
                applyZoom(zoomScale, coordinator: context.coordinator)
            }
            if context.coordinator.currentRotationY != rotationY {
                applyRotation(rotationY, coordinator: context.coordinator)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func logDeferred(_ message: String) {
        let callback = onLog
        DispatchQueue.main.async {
            callback(message)
        }
    }

    private func attach(
        _ model: Entity,
        isSpeaking: Bool,
        zoomScale: Float,
        rotationY: Float,
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
        let targetHeight: Float = 1.60
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

        // Put the model's midpoint at the viewport center; do not add an upward offset.
        let midBodyY = targetHeight / 2.0
        let anchor = AnchorEntity(world: SIMD3<Float>(0, -midBodyY - 0.10, -2.8))
        let zoomPivot = Entity()
        zoomPivot.addChild(model)
        model.position = coordinator.basePosition
        model.scale = coordinator.baseScale
        anchor.addChild(zoomPivot)
        coordinator.rotationPivot = anchor
        coordinator.zoomPivot = zoomPivot
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)

        if coordinator.animationController == nil {
            if let skin = findEntity(named: "skin0", in: model) {
                logAnimationInventory(for: skin)

                // Diagnostic A/B test: play the first imported TempMotion clip,
                // not the default subtree animation previously tested at skin0#20.
                let testClipIndex = 0
                if skin.availableAnimations.indices.contains(testClipIndex) {
                    let clip = skin.availableAnimations[testClipIndex]
                    let definition = clip.definition
                    let loopingClip = clip.repeat(duration: .infinity)
                    let controller = skin.playAnimation(loopingClip, transitionDuration: 0.25, startsPaused: !isSpeaking)
                    coordinator.animationController = controller
                    coordinator.lastIsSpeaking = isSpeaking
                    let controllerEntity = controller.entity
                    logDeferred("[ALINA ANIMATION TEST] started after scene attach; owner=skin0; clipIndex=\(testClipIndex); name=\(clip.name ?? "unnamed"); duration=\(controller.duration); target=\(String(reflecting: definition.bindTarget)); definitionType=\(String(reflecting: type(of: definition))); controllerEntity=\(controllerEntity?.name ?? "nil"); controllerTargetsSkin=\(controllerEntity === skin); playing=\(controller.isPlaying); valid=\(controller.isValid)")
                    let callback = onLog
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard let current = coordinator.animationController else {
                            callback("[ALINA ANIMATION TEST] controller missing at +0.5s")
                            return
                        }
                        callback("[ALINA ANIMATION TEST] +0.5s playing=\(current.isPlaying); valid=\(current.isValid); complete=\(current.isComplete); time=\(current.time)/\(current.duration)")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        guard let current = coordinator.animationController else {
                            callback("[ALINA ANIMATION TEST] controller missing at +2.0s")
                            return
                        }
                        callback("[ALINA ANIMATION TEST] +2.0s playing=\(current.isPlaying); valid=\(current.isValid); complete=\(current.isComplete); time=\(current.time)/\(current.duration)")
                    }
                } else {
                    logDeferred("[ALINA ANIMATION TEST] skin0#\(testClipIndex) unavailable; count=\(skin.availableAnimations.count)")
                }
            } else {
                logDeferred("[ALINA ANIMATION TEST] skin0 entity not found after scene attach")
            }
        }

        applyZoom(zoomScale, coordinator: coordinator)
        applyRotation(rotationY, coordinator: coordinator)
        logDeferred("[ALINA SCALE] height=\(height) baseScale=\(baseScale) offsetY=\(modelOffsetY)")
    }

    private func logAnimationInventory(for skin: Entity) {
        for (index, animation) in skin.availableAnimations.enumerated() {
            let definition = animation.definition
            var details = "[ALINA ANIMATION INVENTORY] skin0#\(index) name=\(animation.name ?? "unnamed"); duration=\(definition.duration); target=\(String(reflecting: definition.bindTarget)); definitionType=\(String(reflecting: type(of: definition))); blendLayer=\(definition.blendLayer); speed=\(definition.speed); delay=\(definition.delay); repeatMode=\(String(reflecting: definition.repeatMode))"
            logDeferred(details)
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

    final class Coordinator {
        var currentEntity: Entity?
        var animationController: AnimationPlaybackController?
        var lastIsSpeaking = false
        var rotationPivot: AnchorEntity?
        var zoomPivot: Entity?
        var baseScale = SIMD3<Float>(repeating: 1)
        var basePosition = SIMD3<Float>(repeating: 0)
        var currentZoom: Float = 1
        var currentRotationY: Float = 0
        var didLogLayout = false
        var didLogUpdate = false
    }
}
