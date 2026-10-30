import Combine
import RealityKit
import SwiftUI

struct AraAvatarView: View {
    enum Clip: String { case idle = "Ara-Idle", wave = "Ara-Wave", talk = "Ara-Talk" }
    let clip: Clip
    let onLog: (String) -> Void
    @StateObject private var loader = AraAvatarLoader()
    @AppStorage("ara_avatar_zoom_scale") private var savedZoomScale = 1.0
    @State private var pinchStartScale = 1.0

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                savedZoomScale = min(max(pinchStartScale * Double(magnification), 0.7), 3.0)
            }
            .onEnded { _ in
                pinchStartScale = savedZoomScale
                onLog("[ARA] Zoom saved: \(String(format: "%.2f", savedZoomScale))x")
            }
    }

    var body: some View {
        ZStack {
            if let entity = loader.entity {
                AraRealityView(entity: entity, zoomScale: Float(savedZoomScale))
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(loader.status).font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding()
            }
        }
        .contentShape(Rectangle())
        .gesture(zoomGesture)
        .task {
            pinchStartScale = savedZoomScale
            loader.onLog = onLog
            loader.show(clip)
        }
        .onChange(of: clip) { loader.show($0) }
        .onReceive(loader.$status.dropFirst()) { status in
            onLog("[ARA] \(status)")
        }
    }
}

@MainActor
private final class AraAvatarLoader: ObservableObject {
    @Published var entity: Entity?
    @Published var status = "Đang nạp avatar Ara…"
    var onLog: ((String) -> Void)?
    private var activeClip: AraAvatarView.Clip?
    private var loadID = 0
    private var loadSubscription: AnyCancellable?

    func show(_ clip: AraAvatarView.Clip) {
        guard activeClip != clip || entity == nil else { return }
        activeClip = clip
        loadID += 1
        let requestID = loadID
        loadSubscription?.cancel()
        entity = nil
        status = "Đang nạp \(clip.rawValue) từ app bundle…"

        guard let url = Bundle.main.url(forResource: clip.rawValue, withExtension: "usdz") else {
            status = "Không tìm thấy \(clip.rawValue).usdz trong app bundle"
            onLog?("[ARA] Bundle lookup failed: \(clip.rawValue).usdz")
            return
        }
        onLog?("[ARA] Found bundled asset: \(url.lastPathComponent)")

        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.status = "Lỗi nạp model"
                }
            }, receiveValue: { [weak self] model in
                guard let self, requestID == self.loadID else { return }
                guard let animation = model.availableAnimations.first else {
                    self.status = "Đã nạp model nhưng không có animation"
                    return
                }
                model.playAnimation(animation.repeat())
                self.entity = model
                self.status = "Đã nạp \(clip.rawValue) từ app bundle"
            })
    }
}

private struct AraRealityView: UIViewRepresentable {
    let entity: Entity
    let zoomScale: Float

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, zoomScale: zoomScale, to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        if context.coordinator.currentEntity !== entity {
            attach(entity, zoomScale: zoomScale, to: view, coordinator: context.coordinator)
        } else if context.coordinator.currentZoom != zoomScale {
            applyZoom(zoomScale, to: entity, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func attach(_ model: Entity, zoomScale: Float, to view: ARView, coordinator: Coordinator) {
        let bounds = model.visualBounds(recursive: true, relativeTo: model)
        let height = bounds.extents.y
        let baseScale: Float = height.isFinite && height > 0 ? 1.35 / height : 1
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        coordinator.basePosition = -bounds.center * baseScale
        coordinator.currentEntity = model

        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.4))
        anchor.addChild(model)
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)
        applyZoom(zoomScale, to: model, coordinator: coordinator)
    }

    private func applyZoom(_ zoom: Float, to model: Entity, coordinator: Coordinator) {
        model.scale = coordinator.baseScale * zoom
        model.position = coordinator.basePosition * zoom
        coordinator.currentZoom = zoom
    }

    final class Coordinator {
        var currentEntity: Entity?
        var baseScale = SIMD3<Float>(repeating: 1)
        var basePosition = SIMD3<Float>(repeating: 0)
        var currentZoom: Float = 1
    }
}
