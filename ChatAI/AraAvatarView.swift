import Combine
import CryptoKit
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
        .onReceive(loader.$status.dropFirst()) { onLog("[ARA] \($0)") }
    }
}

@MainActor
private final class AraAvatarLoader: ObservableObject {
    @Published var entity: Entity?
    @Published var status = "Đang tải avatar Ara…"
    var onLog: ((String) -> Void)?

    private var activeClip: AraAvatarView.Clip?
    private var loadID = 0
    private var loadSubscription: AnyCancellable?

    private let assets: [AraAvatarView.Clip: (url: String, sha256: String)] = [
        .idle: (
            "https://github.com/tpios-tp2586/Chat-ai-tpios/releases/download/ara-avatar-v1/Ara-Idle.usdz",
            "cafb0757cf9ae7067722d0f782422abec57d58da24e638c55a1a446984186201"
        ),
        .talk: (
            "https://github.com/tpios-tp2586/Chat-ai-tpios/releases/download/ara-avatar-v1/Ara-Talk.usdz",
            "f1885941f9cdc4d71e67c19ca3e93b0c4edaaa9c1af20b3636ee12f8acc251dd"
        ),
        .wave: (
            "https://github.com/tpios-tp2586/Chat-ai-tpios/releases/download/ara-avatar-v1/Ara-Wave.usdz",
            "657db823be57368b0f5b1cfa4f6fa73c2ba112107e5adaca74cc008ded82ffc2"
        )
    ]

    func show(_ clip: AraAvatarView.Clip) {
        guard activeClip != clip || entity == nil else { return }
        activeClip = clip
        loadID += 1
        let requestID = loadID
        loadSubscription?.cancel()
        status = "Đang chuẩn bị \(clip.rawValue)…"

        Task {
            do {
                let url = try await localURL(for: clip)
                guard requestID == loadID else { return }
                loadSubscription = Entity.loadAsync(contentsOf: url)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.status = "Lỗi tải model: \(error.localizedDescription)"
                        }
                    }, receiveValue: { [weak self] model in
                        guard let self, requestID == self.loadID else { return }
                        if let animation = model.availableAnimations.first {
                            model.playAnimation(animation.repeat())
                        }
                        self.entity = model
                        self.status = "Đã tải \(clip.rawValue)"
                    })
            } catch {
                guard requestID == loadID else { return }
                status = "Không tải được \(clip.rawValue): \(error.localizedDescription)"
            }
        }
    }

    private func localURL(for clip: AraAvatarView.Clip) async throws -> URL {
        guard let asset = assets[clip] else { throw URLError(.badURL) }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AraAvatar/ara-avatar-v1", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("\(clip.rawValue).usdz")

        if FileManager.default.fileExists(atPath: destination.path),
           try sha256(of: destination) == asset.sha256 {
            return destination
        }

        status = "Đang tải \(clip.rawValue) (khoảng 34 MB)…"
        let (temporaryURL, response) = try await URLSession.shared.download(from: URL(string: asset.url)!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let digest = try sha256(of: temporaryURL)
        guard digest == asset.sha256 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw URLError(.cannotDecodeContentData)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct AraRealityView: UIViewRepresentable {
    let entity: Entity

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        attach(entity, to: view)
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
