import Combine
import RealityKit
import SwiftUI

struct AraAvatarView: View {
    enum Clip: String { case idle = "Ara-Idle", wave = "Ara-Wave", talk = "Ara-Talk" }
    let clip: Clip
    let onLog: (String) -> Void
    @StateObject private var loader = AraAvatarLoader()

    var body: some View {
        ZStack {
            if let entity = loader.entity {
                AraRealityView(entity: entity)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(loader.status).font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding()
            }
        }
        .task { loader.onLog = onLog; loader.show(clip) }
        .onChange(of: clip) { loader.show($0) }
        .onReceive(loader.$status.dropFirst()) { onLog("[ARA] \\($0)") }
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
        status = "Đang nạp \\(clip.rawValue) từ app bundle…"

        guard let url = Bundle.main.url(forResource: clip.rawValue, withExtension: "usdz") else {
            status = "Không tìm thấy \\(clip.rawValue).usdz trong app bundle"
            onLog?("[ARA] Bundle lookup failed: \\(clip.rawValue).usdz")
            return
        }
        onLog?("[ARA] Found bundled asset: \\(url.lastPathComponent)")

        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.status = "Lỗi nạp model: \\(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] model in
                guard let self, requestID == self.loadID else { return }
                guard let animation = model.availableAnimations.first else {
                    self.status = "Đã nạp model nhưng không có animation"
                    return
                }
                model.playAnimation(animation.repeat())
                self.entity = model
                self.status = "Đã nạp \\(clip.rawValue) từ app bundle"
            })
    }
}

private struct AraRealityView: UIViewRepresentable {
    let entity: Entity

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, to: view)
        context.coordinator.currentEntity = entity
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        if context.coordinator.currentEntity !== entity {
            attach(entity, to: view)
            context.coordinator.currentEntity = entity
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func attach(_ model: Entity, to view: ARView) {
        let bounds = model.visualBounds(recursive: true, relativeTo: model)
        let height = bounds.extents.y
        if height.isFinite && height > 0 {
            let scale = 1.35 / height
            model.scale = SIMD3<Float>(repeating: scale)
            model.position = -bounds.center * scale
        }
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.4))
        anchor.addChild(model)
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)
    }

    final class Coordinator {
        var currentEntity: Entity?
    }
}