import Combine
import RealityKit
import SwiftUI

// MARK: - Public types

enum AraEmotion: Equatable {
    case idle, speaking, listening, thinking, happy, surprised, empathy
}

// MARK: - Clip index map
// Source: Ara-Avatar.usdz v5, availableAnimations order confirmed batch-30 test
// 0=Idle 1=Wave 2=Talk 3=TalkExplain 4=AraListening 5=AraThinking
// 6=AraEmpathy 7=AraLaugh 8=Walk 9=Run 10=WalkBack 11=StrafeL 12=StrafeR
// 13=JumpStart 14=JumpAir 15=JumpLand 16=SitDown 17=SitIdle 18=StandUp
// 19=LieDown 20=Sleep 21=TurnL45 22=TurnL90 23=TurnR45 24=TurnR90
// 25=Turn360 26=Laugh 27=Cheer

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
    static let laugh       = AraClip(name: "Laugh",        index: 26, duration: 2.4,  loops: false)
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

    private var clips: [AnimationResource] = []
    private var controller: AnimationPlaybackController?
    private var speakingTask: Task<Void, Never>?
    private var hasWaved = false
    private var currentEmotion: AraEmotion = .idle
    private var loaded = false

    // MARK: Load

    func load() {
        guard !loaded else { return }
        loaded = true
        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz"
            onLog?("[ARA ERROR] Ara-Avatar.usdz missing from bundle")
            return
        }
        onLog?("[ARA] loading Ara-Avatar.usdz")
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let model = try await Entity.load(contentsOf: url)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // Collect animations recursively
                    func collect(_ e: Entity) -> [AnimationResource] {
                        var r = e.availableAnimations
                        for c in e.children { r += collect(c) }
                        return r
                    }
                    let all = collect(model)
                    self.onLog?("[ARA] loaded, clips=\(all.count)")
                    if all.isEmpty {
                        self.status = "Ara loaded (no animations)"
                        self.onLog?("[ARA ERROR] no animations found in USDZ")
                        self.entity = model
                        return
                    }
                    self.clips = all
                    model.stopAllAnimations()
                    self.entity = model
                    self.status = "Ara sẵn sàng"
                    // Play idle after entity enters scene (slight delay for ARView attach)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        self.play(AraClips.idle)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.status = "Lỗi nạp Ara: \(error.localizedDescription)"
                    self?.onLog?("[ARA ERROR] load failed: \(error)")
                }
            }
        }
    }

    // MARK: Emotion

    func setEmotion(_ emotion: AraEmotion) {
        guard clips.isEmpty == false else { return }
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
            startSpeaking()
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

    private func startSpeaking() {
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

    // MARK: Playback

    private func play(_ clip: AraClip) {
        guard let entity = entity else { return }
        guard clip.index < clips.count else {
            onLog?("[ARA ERROR] index \(clip.index) out of range (total=\(clips.count))")
            return
        }
        let anim = clips[clip.index]
        let final = clip.loops ? anim.repeat(duration: .infinity) : anim
        controller?.stop()
        controller = entity.playAnimation(final, transitionDuration: 0.25)
        // Check if entity is in a scene
        let inScene = entity.scene != nil
        onLog?("[ARA] play[\(clip.index)] \(clip.name) inScene=\(inScene)")
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
