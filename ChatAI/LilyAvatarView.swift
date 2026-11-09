import Combine
import RealityKit
import SwiftUI

struct LilyAvatarView: View {
    let onLog: (String) -> Void
    let onTap: () -> Void

    @StateObject private var loader = LilyAvatarLoader()
    @AppStorage("lily_avatar_zoom_scale_v7") private var savedZoomScale = 2.5
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

        let worldBounds = model.visualBounds(recursive: true, relativeTo: nil)
        let localBounds = model.visualBounds(recursive: true, relativeTo: model)
        logDeferred("[LILY DEBUG] pre-fit world bounds center=\(worldBounds.center), extents=\(worldBounds.extents)")
        logDeferred("[LILY DEBUG] pre-fit local bounds center=\(localBounds.center), extents=\(localBounds.extents)")

        // Match Ara's fitting method: measure in model-local space and normalize to 1.6 units.
        let height = localBounds.extents.y
        let importedRootScale = model.scale
        let baseScale: Float = (height.isFinite && height > 0) ? 1.6 / height : 1
        logDeferred("[LILY SCALE] localHeight=\(height), targetHeight=1.6, baseScale=\(baseScale), importedRootScale=\(importedRootScale), savedZoom=\(zoomScale)")
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        coordinator.basePosition = -localBounds.center * baseScale
        coordinator.currentEntity = model

        let anchorPosition = SIMD3<Float>(0, 0, -2.8)
        let anchor = AnchorEntity(world: anchorPosition)
        let zoomPivot = Entity()
        zoomPivot.addChild(model)
        model.position = coordinator.basePosition
        model.scale = coordinator.baseScale
        anchor.addChild(zoomPivot)
        coordinator.rotationPivot = anchor
        coordinator.zoomPivot = zoomPivot
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)
        model.stopAllAnimations()
        applyZoom(zoomScale, coordinator: coordinator)
        applyRotation(rotationY, coordinator: coordinator)

        logDeferred("[LILY DEBUG] applied transform: modelPosition=\(model.position), modelScale=\(model.scale), zoomPivotScale=\(zoomPivot.scale), anchorPosition=\(anchorPosition), viewport=\(view.bounds.size)")
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
