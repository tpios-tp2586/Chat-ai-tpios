import Combine
import RealityKit
import SwiftUI

struct LilyAvatarView: View {
    let onLog: (String) -> Void
    let onTap: () -> Void

    @StateObject private var loader = LilyAvatarLoader()
    @AppStorage("lily_avatar_zoom_scale_v3") private var savedZoomScale = 1.0
    @State private var pinchStartScale = 1.0
    @State private var rotationY: Float = 0
    @State private var dragStartRotation: Float = 0

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { savedZoomScale = min(max(pinchStartScale * Double($0), 0.5), 1.5) }
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
                LilyRealityView(entity: entity, zoomScale: Float(savedZoomScale), rotationY: rotationY, onLog: onLog)
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
private final class LilyAvatarLoader: ObservableObject {
    @Published var entity: Entity?
    @Published var status = "Đang nạp Lily…"
    var onLog: ((String) -> Void)?
    private var loaded = false

    func load() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "Lily", withExtension: "usdz") else {
            status = "Không tìm thấy Lily.usdz"
            onLog?("[LILY ERROR] Lily.usdz missing from app bundle")
            return
        }

        onLog?("[LILY] loading Lily.usdz")
        Task { @MainActor in
            do {
                let model = try await Entity.load(contentsOf: url)
                func collect(_ entity: Entity) -> [AnimationResource] {
                    entity.availableAnimations + entity.children.flatMap(collect)
                }
                let animations = collect(model)
                onLog?("[LILY] loaded; animations=\(animations.count); animation playback disabled pending validation")
                onLog?("[LILY DEBUG] publishing root entity; name=\(model.name), children=\(model.children.count), enabled=\(model.isEnabled)")
                model.stopAllAnimations()
                entity = model
                status = "Lily đã sẵn sàng"
            } catch {
                status = "Lỗi nạp Lily: \(error.localizedDescription)"
                onLog?("[LILY ERROR] load failed: \(error)")
            }
        }
    }
}

private struct LilyRealityView: UIViewRepresentable {
    let entity: Entity
    let zoomScale: Float
    let rotationY: Float
    let onLog: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        logDeferred("[LILY DEBUG] makeUIView entered")
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, zoomScale: zoomScale, rotationY: rotationY, to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        if !context.coordinator.didLogUpdate {
            logDeferred("[LILY DEBUG] updateUIView entered; bounds=\(view.bounds.size)")
            context.coordinator.didLogUpdate = true
        }
        if !context.coordinator.didLogLayout, view.bounds.width > 0, view.bounds.height > 0 {
            logDeferred("[LILY DEBUG] ARView layout size=\(view.bounds.size)")
            context.coordinator.didLogLayout = true
        }
        if context.coordinator.currentEntity !== entity {
            attach(entity, zoomScale: zoomScale, rotationY: rotationY, to: view, coordinator: context.coordinator)
        } else {
            if context.coordinator.currentZoom != zoomScale {
                applyZoom(zoomScale, to: entity, coordinator: context.coordinator)
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
        zoomScale: Float,
        rotationY: Float,
        to view: ARView,
        coordinator: Coordinator
    ) {
        logDeferred("[LILY DEBUG] attach entered; original root position=\(model.position), scale=\(model.scale), children=\(model.children.count), enabled=\(model.isEnabled)")
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
                logDeferred("[LILY MESH] path=\(path), name=\(node.name), enabledBeforeForce=\(wasEnabled), position=\(node.position), scale=\(node.scale), localCenter=\(localBounds.center), localExtents=\(localBounds.extents), worldCenter=\(worldBounds.center), worldExtents=\(worldBounds.extents)")
            } else if depth <= 2 {
                logDeferred("[LILY NODE] path=\(path), name=\(node.name), enabledBeforeForce=\(wasEnabled), position=\(node.position), scale=\(node.scale), children=\(node.children.count)")
            }

            for (index, child) in node.children.enumerated() {
                inspectHierarchy(child, path: "\(path)/\(index)", depth: depth + 1)
            }
        }

        inspectHierarchy(model, path: "root", depth: 0)
        logDeferred("[LILY DEBUG] imported hierarchy: inspectedNodes=\(inspectedNodes), meshNodes=\(meshNodes), originallyDisabledNodes=\(originallyDisabledNodes), rootChildren=\(model.children.count)")

        func enableAll(_ node: Entity) {
            node.isEnabled = true
            for child in node.children { enableAll(child) }
        }
        enableAll(model)
        logDeferred("[LILY DEBUG] hierarchy enabled after inspection")

        let bounds = model.visualBounds(recursive: true, relativeTo: nil)
        let localBounds = model.visualBounds(recursive: true, relativeTo: model)
        logDeferred("[LILY DEBUG] pre-fit world bounds center=\(bounds.center), extents=\(bounds.extents)")
        logDeferred("[LILY DEBUG] pre-fit local bounds center=\(localBounds.center), extents=\(localBounds.extents)")
        let height = bounds.extents.y

        // Temporary diagnostic fit: target a smaller 0.32-world-unit character height.
        let targetHeight: Float = 0.32
        let baseScale: Float = (height.isFinite && height > 0.1) ? targetHeight / height : 0.3
        logDeferred("[LILY TEST SCALE] measuredHeight=\(height), targetHeight=\(targetHeight), baseScale=\(baseScale), savedZoom=\(zoomScale)")
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        coordinator.basePosition = SIMD3<Float>(
            -bounds.center.x * baseScale,
            -bounds.center.y * baseScale,
            -bounds.center.z * baseScale
        )
        coordinator.currentEntity = model

        let anchorPosition = SIMD3<Float>(0, 0, -2.0)
        let anchor = AnchorEntity(world: anchorPosition)
        anchor.addChild(model)
        coordinator.rotationPivot = anchor
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)
        model.stopAllAnimations()
        applyZoom(zoomScale, to: model, coordinator: coordinator)
        applyRotation(rotationY, coordinator: coordinator)

        logDeferred("[LILY DEBUG] applied transform: modelPosition=\(model.position), modelScale=\(model.scale), anchorPosition=\(anchorPosition), viewport=\(view.bounds.size)")
    }

    private func applyZoom(_ zoom: Float, to model: Entity, coordinator: Coordinator) {
        model.scale = coordinator.baseScale * zoom
        model.position = coordinator.basePosition * zoom
        coordinator.currentZoom = zoom
    }

    private func applyRotation(_ rotation: Float, coordinator: Coordinator) {
        guard let pivot = coordinator.rotationPivot else { return }
        pivot.orientation = simd_quatf(angle: rotation, axis: SIMD3<Float>(0, 1, 0))
        coordinator.currentRotationY = rotation
    }

    final class Coordinator {
        var currentEntity: Entity?
        var rotationPivot: AnchorEntity?
        var baseScale = SIMD3<Float>(repeating: 1)
        var basePosition = SIMD3<Float>(repeating: 0)
        var currentZoom: Float = 1
        var currentRotationY: Float = 0
        var didLogLayout = false
        var didLogUpdate = false
    }
}
