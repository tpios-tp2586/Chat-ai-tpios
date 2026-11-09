import Combine
import RealityKit
import SwiftUI

struct LilyAvatarView: View {
    let onLog: (String) -> Void

    @StateObject private var loader = LilyAvatarLoader()
    @AppStorage("lily_avatar_zoom_scale_v1") private var savedZoomScale = 2.5
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
                LilyRealityView(entity: entity, zoomScale: Float(savedZoomScale), rotationY: rotationY)
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

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, zoomScale: zoomScale, rotationY: rotationY, to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func attach(
        _ model: Entity,
        zoomScale: Float,
        rotationY: Float,
        to view: ARView,
        coordinator: Coordinator
    ) {
        func enableAll(_ entity: Entity) {
            entity.isEnabled = true
            for child in entity.children { enableAll(child) }
        }
        enableAll(model)

        func findModelBounds(_ entity: Entity) -> BoundingBox? {
            if let model = entity as? ModelEntity {
                return model.visualBounds(recursive: false, relativeTo: nil)
            }
            var combined: BoundingBox?
            for child in entity.children {
                if let bounds = findModelBounds(child) {
                    combined = combined.map { $0.union(bounds) } ?? bounds
                }
            }
            return combined
        }

        let bounds = findModelBounds(model) ?? model.visualBounds(recursive: true, relativeTo: nil)
        let height = bounds.extents.y
        let baseScale: Float = (height.isFinite && height > 0.1) ? 1.6 / height : 0.94
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        coordinator.basePosition = SIMD3<Float>(
            -bounds.center.x * baseScale,
            -bounds.center.y * baseScale,
            -bounds.center.z * baseScale
        )
        coordinator.currentEntity = model

        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.8))
        anchor.addChild(model)
        coordinator.rotationPivot = anchor
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)
        model.stopAllAnimations()
        applyZoom(zoomScale, to: model, coordinator: coordinator)
        applyRotation(rotationY, coordinator: coordinator)
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
    }
}
