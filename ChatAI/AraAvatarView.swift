import Combine
import RealityKit
import SwiftUI

// MARK: - Public types

enum AraEmotion: Equatable {
    case idle, speaking, listening, thinking, happy, surprised, empathy
}

// MARK: - Clip index map
// Confirmed order from availableAnimations on Ara-Avatar.usdz (batch-30 test, ara-avatar-v5):
// 0=Idle 1=Wave 2=Talk 3=TalkExplain 4=AraListening 5=AraThinking
// 6=AraEmpathy 7=AraLaugh 8=Walk 9=Run ... 27=Cheer 28=Laugh 29=Cry

private struct AraClip {
    let name: String
    let index: Int
    let duration: Double
    let loops: Bool
}

private enum AraClips {
    static let idle        = AraClip(name: "Idle",         index: 0,  duration: 3.2,  loops: true)
    static let wave        = AraClip(name: "Wave",         index: 1,  duration: 1.6,  loops: false)
    static let talk        = AraClip(name: "Talk",         index: 2,  duration: 6.4,  loops: false)
    static let talkExplain = AraClip(name: "TalkExplain",  index: 3,  duration: 2.8,  loops: false)
    static let listening   = AraClip(name: "AraListening", index: 4,  duration: 3.2,  loops: true)
    static let thinking    = AraClip(name: "AraThinking",  index: 5,  duration: 3.2,  loops: false)
    static let empathy     = AraClip(name: "AraEmpathy",   index: 6,  duration: 3.2,  loops: false)
    static let laugh       = AraClip(name: "AraLaugh",     index: 7,  duration: 2.4,  loops: false)
    static let cheer       = AraClip(name: "Cheer",        index: 27, duration: 1.2,  loops: false)
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
            loader.load()
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

    private var allClips: [AnimationResource] = []
    private var loadSubscription: AnyCancellable?
    private var controller: AnimationPlaybackController?
    private var speakingTask: Task<Void, Never>?
    private var hasWaved = false
    private var currentEmotion: AraEmotion = .idle

    // MARK: - Emotion

    func setEmotion(_ emotion: AraEmotion) {
        // Skip redundant calls unless it's a speaking re-entry
        if emotion == currentEmotion && speakingTask == nil && emotion != .speaking { return }
        currentEmotion = emotion
        speakingTask?.cancel()
        speakingTask = nil

        switch emotion {
        case .idle:
            play(AraClips.idle)
        case .listening:
            play(AraClips.listening)
        case .thinking:
            play(AraClips.thinking)
            scheduleReturn(to: .listening, after: AraClips.thinking.duration + 0.3)
        case .speaking:
            startSpeakingLoop()
        case .happy:
            play(AraClips.laugh)
            scheduleReturn(to: .idle, after: AraClips.laugh.duration + 0.3)
        case .surprised:
            play(AraClips.cheer)
            scheduleReturn(to: .idle, after: AraClips.cheer.duration + 0.3)
        case .empathy:
            play(AraClips.empathy)
            scheduleReturn(to: .idle, after: AraClips.empathy.duration + 0.3)
        }
    }

    private func startSpeakingLoop() {
        speakingTask = Task { [weak self] in
            guard let self else { return }
            if !self.hasWaved {
                self.hasWaved = true
                self.play(AraClips.wave)
                self.onLog?("[ARA] wave")
                try? await Task.sleep(nanoseconds: UInt64(AraClips.wave.duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
            }
            var cycle = 0
            while !Task.isCancelled {
                let clip = (cycle % 3 == 2) ? AraClips.talkExplain : AraClips.talk
                self.play(clip)
                self.onLog?("[ARA] \(clip.name) cycle=\(cycle)")
                try? await Task.sleep(nanoseconds: UInt64((clip.duration - 0.25) * 1_000_000_000))
                cycle += 1
            }
        }
    }

    private func scheduleReturn(to emotion: AraEmotion, after seconds: Double) {
        speakingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.setEmotion(emotion)
        }
    }

    // MARK: - Playback

    private func play(_ clip: AraClip) {
        guard let entity = entity else { return }
        guard clip.index < allClips.count else {
            onLog?("[ARA ERROR] index \(clip.index) out of range (total=\(allClips.count))")
            return
        }
        let anim = allClips[clip.index]
        let final = clip.loops ? anim.repeat(duration: .infinity) : anim
        controller?.stop()
        controller = entity.playAnimation(final, transitionDuration: 0.25)
        onLog?("[ARA] play[\(clip.index)] \(clip.name)")
    }

    // MARK: - Load

    func load() {
        guard entity == nil, loadSubscription == nil else { return }
        status = "Đang nạp Ara-Avatar.usdz…"
        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz"
            onLog?("[ARA ERROR] bundle lookup failed")
            return
        }
        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.loadSubscription = nil
                if case .failure(let e) = completion {
                    self?.status = "Lỗi: \(e.localizedDescription)"
                    self?.onLog?("[ARA ERROR] load failed: \(e)")
                }
            }, receiveValue: { [weak self] model in
                guard let self else { return }
                self.loadSubscription = nil

                // Collect all availableAnimations recursively
                func collect(_ e: Entity) -> [AnimationResource] {
                    var r = e.availableAnimations
                    for c in e.children { r += collect(c) }
                    return r
                }
                let clips = collect(model)
                self.allClips = clips
                self.onLog?("[ARA] \(clips.count) clips loaded")

                model.stopAllAnimations()
                self.entity = model
                self.status = "Ara sẵn sàng"

                // Start idle
                self.play(AraClips.idle)
            })
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
