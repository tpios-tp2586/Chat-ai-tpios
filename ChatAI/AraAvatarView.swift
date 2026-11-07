import Combine
import RealityKit
import SwiftUI

// MARK: - Public types

enum AraEmotion: Equatable {
    case idle, speaking, listening, thinking, happy, surprised, empathy
}

// MARK: - Clip definitions

private enum AraClip: String, CaseIterable {
    case idle        = "Ara-Idle"
    case wave        = "Ara-Wave"
    case talk        = "Ara-Talk"
    case talkExplain = "Ara-TalkExplain"
    case listening   = "Ara-AraListening"
    case thinking    = "Ara-AraThinking"
    case empathy     = "Ara-AraEmpathy"
    case laugh       = "Ara-Laugh"
    case cheer       = "Ara-Cheer"

    var duration: Double {
        switch self {
        case .idle:        return 3.20
        case .wave:        return 1.60
        case .talk:        return 6.40
        case .talkExplain: return 2.80
        case .listening:   return 3.20
        case .thinking:    return 3.20
        case .empathy:     return 3.20
        case .laugh:       return 2.40
        case .cheer:       return 1.20
        }
    }

    var loops: Bool {
        switch self {
        case .idle, .listening: return true
        default:                return false
        }
    }
}

// MARK: - View

struct AraAvatarView: View {
    let emotion: AraEmotion
    let onLog: (String) -> Void

    @StateObject private var loader = AraAvatarLoader()
    @AppStorage("ara_avatar_zoom_scale_v3") private var savedZoomScale = 2.5
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
                AraRealityView(entity: entity, zoomScale: Float(savedZoomScale), rotationY: rotationY)
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
        .simultaneousGesture(rotationGesture)
        .task {
            pinchStartScale = savedZoomScale
            loader.onLog = onLog
            loader.setEmotion(.idle)
        }
        .onChange(of: emotion) { loader.setEmotion($0) }
    }
}

// MARK: - Loader

@MainActor
private final class AraAvatarLoader: ObservableObject {
    @Published var entity: Entity?
    @Published var status = "Đang nạp Ara…"
    var onLog: ((String) -> Void)?

    private var currentClip: AraClip?
    private var loadID = 0
    private var loadSubscription: AnyCancellable?
    private var cache: [AraClip: Entity] = [:]
    private var speakingTask: Task<Void, Never>?
    private var hasWaved = false

    // MARK: Emotion

    func setEmotion(_ emotion: AraEmotion) {
        switch emotion {
        case .idle:
            cancel()
            show(.idle)
        case .listening:
            cancel()
            show(.listening)
        case .thinking:
            cancel()
            show(.thinking)
            scheduleReturn(to: .listening, after: AraClip.thinking.duration + 0.3)
        case .speaking:
            startSpeaking()
        case .happy:
            cancel()
            show(.laugh)
            scheduleReturn(to: .idle, after: AraClip.laugh.duration + 0.3)
        case .surprised:
            cancel()
            show(.cheer)
            scheduleReturn(to: .idle, after: AraClip.cheer.duration + 0.3)
        case .empathy:
            cancel()
            show(.empathy)
            scheduleReturn(to: .idle, after: AraClip.empathy.duration + 0.3)
        }
    }

    private func startSpeaking() {
        cancel()
        speakingTask = Task { [weak self] in
            guard let self else { return }
            if !self.hasWaved {
                self.hasWaved = true
                self.show(.wave)
                self.onLog?("[ARA] wave")
                try? await Task.sleep(nanoseconds: UInt64(AraClip.wave.duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
            }
            var cycle = 0
            while !Task.isCancelled {
                let clip: AraClip = (cycle % 3 == 2) ? .talkExplain : .talk
                self.show(clip)
                self.onLog?("[ARA] \(clip.rawValue) cycle=\(cycle)")
                try? await Task.sleep(nanoseconds: UInt64((clip.duration - 0.25) * 1_000_000_000))
                cycle += 1
            }
        }
    }

    private func cancel() {
        speakingTask?.cancel()
        speakingTask = nil
    }

    private func scheduleReturn(to emotion: AraEmotion, after seconds: Double) {
        speakingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.setEmotion(emotion)
        }
    }

    // MARK: Show clip

    func show(_ clip: AraClip) {
        if currentClip == clip && entity != nil { return }
        currentClip = clip
        loadID += 1
        let reqID = loadID
        loadSubscription?.cancel()

        if let cached = cache[clip] {
            play(cached, clip: clip)
            entity = cached
            onLog?("[ARA] \(clip.rawValue) (cache)")
            return
        }

        status = entity == nil ? "Đang nạp \(clip.rawValue)…" : "Chuyển \(clip.rawValue)…"

        // Debug: log all USDZ files in bundle
        let allUSDZ = Bundle.main.paths(forResourcesOfType: "usdz", inDirectory: nil)
        onLog?("[ARA BUNDLE] \(allUSDZ.count) usdz files: \(allUSDZ.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", "))")

        guard let url = Bundle.main.url(forResource: clip.rawValue, withExtension: "usdz") else {
            status = "Không tìm thấy \(clip.rawValue).usdz"
            onLog?("[ARA ERROR] missing \(clip.rawValue).usdz")
            return
        }

        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let e) = completion {
                    self?.status = "Lỗi nạp \(clip.rawValue)"
                    self?.onLog?("[ARA ERROR] \(clip.rawValue): \(e)")
                }
            }, receiveValue: { [weak self] model in
                guard let self, reqID == self.loadID else { return }
                guard model.availableAnimations.first != nil else {
                    self.status = "\(clip.rawValue) không có animation"
                    self.onLog?("[ARA ERROR] \(clip.rawValue) no animations")
                    return
                }
                self.cache[clip] = model
                self.play(model, clip: clip)
                self.entity = model
                self.status = "Ara sẵn sàng"
                self.onLog?("[ARA] loaded \(clip.rawValue)")
            })
    }

    private func play(_ model: Entity, clip: AraClip) {
        guard let anim = model.availableAnimations.first else { return }
        model.stopAllAnimations()
        let final = clip.loops ? anim.repeat(duration: .infinity) : anim
        model.playAnimation(final, transitionDuration: 0.25)
    }
}

// MARK: - RealityView

private struct AraRealityView: UIViewRepresentable {
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

    private func attach(_ model: Entity, zoomScale: Float, rotationY: Float,
                        to view: ARView, coordinator: Coordinator) {
        let bounds = model.visualBounds(recursive: true, relativeTo: model)
        let height = bounds.extents.y
        let baseScale: Float = height.isFinite && height > 0 ? 1.6 / height : 1
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        coordinator.basePosition = -bounds.center * baseScale
        coordinator.currentEntity = model
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.8))
        anchor.addChild(model)
        coordinator.rotationPivot = anchor
        view.scene.anchors.removeAll()
        view.scene.addAnchor(anchor)
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
