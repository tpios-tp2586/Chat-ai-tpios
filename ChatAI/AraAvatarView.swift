import Combine
import RealityKit
import SwiftUI

struct AraAvatarView: View {
    enum Clip: String {
        case idle = "Idle"
        case wave = "Wave"
        case talk = "Talk"
        case talkExplain = "TalkExplain"

        var loops: Bool { self == .idle || self == .talk }
    }

    let clip: Clip
    let onLog: (String) -> Void
    @StateObject private var loader = AraAvatarLoader()
    @AppStorage("ara_avatar_zoom_scale_v3") private var savedZoomScale = 2.5
    @State private var pinchStartScale = 1.0

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                savedZoomScale = min(max(pinchStartScale * Double(magnification), 0.7), 4.5)
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
        .simultaneousGesture(zoomGesture)
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

    private var requestedClip: AraAvatarView.Clip?
    private var activeClip: AraAvatarView.Clip?
    private var animations: [String: AnimationResource] = [:]
    private var loadSubscription: AnyCancellable?
    private var playback: AnimationPlaybackController?

    func show(_ clip: AraAvatarView.Clip) {
        requestedClip = clip
        guard let entity else {
            guard loadSubscription == nil else { return }
            load()
            return
        }
        guard activeClip != clip else { return }
        play(clip, on: entity)
    }

    private func load() {
        status = "Đang nạp Ara-Avatar.usdz từ app bundle…"
        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz trong app bundle"
            onLog?("[ARA] Bundle lookup failed: Ara-Avatar.usdz")
            return
        }
        onLog?("[ARA] Found bundled asset: \(url.lastPathComponent)")

        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.loadSubscription = nil
                if case .failure(let error) = completion {
                    self.status = "Lỗi nạp Ara-Avatar.usdz: \(error.localizedDescription)"
                    self.onLog?("[ARA] USDZ load failed: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] model in
                guard let self else { return }
                self.entity = model
                self.animations.removeAll()
                for animation in model.availableAnimations {
                    self.animations[animation.name.lowercased()] = animation
                }
                let names = model.availableAnimations.map(\.name).joined(separator: ", ")
                self.onLog?("[ARA] Imported animations (\(model.availableAnimations.count)): \(names)")
                guard let clip = self.requestedClip else { return }
                self.play(clip, on: model)
            })
    }

    private func play(_ clip: AraAvatarView.Clip, on model: Entity) {
        guard let animation = animations[clip.rawValue.lowercased()] else {
            status = "Không tìm thấy animation \(clip.rawValue) trong Ara-Avatar.usdz"
            onLog?("[ARA] Missing animation: \(clip.rawValue); available: \(animations.keys.sorted().joined(separator: ", "))")
            return
        }

        playback = model.playAnimation(
            clip.loops ? animation.repeat() : animation,
            transitionDuration: 0.25
        )
        activeClip = clip
        status = "Đang phát animation \(clip.rawValue)"
        onLog?("[ARA] Playing \(clip.rawValue) on the same Entity")
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
