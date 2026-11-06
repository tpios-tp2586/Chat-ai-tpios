import Combine
import RealityKit
import SwiftUI

// MARK: - Emotion (public, shared with CompanionChatView)

enum AraEmotion: Equatable {
    case idle, speaking, listening, thinking, happy, surprised, empathy
}

// MARK: - Clip definitions (name + time range from confirmed animation-timeline.json)
// Global USDZ timeline: 0–3539 timecodes @ 60 tc/s ≈ 58.983s total
// Clip offsets verified in ara-avatar-research-bundle / usdz-animation-diagnostics.txt

// Clip index mapping confirmed by batch-30 manual TEST on device
// Order: Idle=0, Wave=1, Talk=2, TalkExplain=3, AraListening=4, AraThinking=5,
//        AraEmpathy=6, AraLaugh=7, Walk=8, Run=9, WalkBack=10, StrafeL=11, StrafeR=12,
//        JumpStart=13, JumpAir=14, JumpLand=15, SitDown=16, SitIdle=17, StandUp=18,
//        LieDown=19, Sleep=20, TurnL45=21, TurnL90=22, TurnR45=23, TurnR90=24, Turn360=25, RideHorse=26
// Duration from animation-timeline.json (approximate seconds)
private struct AraClip {
    let name: String    // display only
    let index: Int      // index in entity.availableAnimations
    let duration: Double
}

private enum AraClips {
    static let idle        = AraClip(name: "Idle",         index: 0,  duration: 3.933)
    static let wave        = AraClip(name: "Wave",         index: 1,  duration: 3.000)
    static let talk        = AraClip(name: "Talk",         index: 2,  duration: 6.400)
    static let talkExplain = AraClip(name: "TalkExplain",  index: 3,  duration: 2.800)
    static let listening   = AraClip(name: "AraListening", index: 4,  duration: 3.200)
    static let thinking    = AraClip(name: "AraThinking",  index: 5,  duration: 3.267)
    static let empathy     = AraClip(name: "AraEmpathy",   index: 6,  duration: 3.200)
    static let laugh       = AraClip(name: "AraLaugh",     index: 7,  duration: 3.133)
    static let cheer       = AraClip(name: "Cheer",        index: 26, duration: 2.467)
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
    @Published var status = "Đang nạp avatar Ara…"
    var onLog: ((String) -> Void)?

    private var loadSubscription: AnyCancellable?
    private var globalAnimation: AnimationResource?  // full USDZ global animation
    private var activeController: AnimationPlaybackController?
    private var currentEmotion: AraEmotion = .idle
    private var speakingTask: Task<Void, Never>?

    // MARK: - Emotion dispatch

    func setEmotion(_ emotion: AraEmotion) {
        guard let entity = entity else { return }
        // Allow re-entry if task was running (speaking loop needs restart)
        let isRedundant = emotion == currentEmotion && speakingTask == nil
        guard !isRedundant else { return }
        let anim = globalAnimation ?? entity.availableAnimations.first
        speakingTask?.cancel()
        speakingTask = nil
        currentEmotion = emotion

        switch emotion {
        case .idle:
            play(clip: AraClips.idle, on: entity, anim: anim, loop: true)

        case .listening:
            play(clip: AraClips.listening, on: entity, anim: anim, loop: true)

        case .thinking:
            play(clip: AraClips.thinking, on: entity, anim: anim, loop: false)
            scheduleReturn(to: .listening, after: AraClips.thinking.duration + 0.3)

        case .speaking:
            // Wave once on first speak, then loop Talk → occasionally TalkExplain
            speakingTask = Task { [weak self] in
                guard let self else { return }
                // Wave greeting (only plays once per session via flag in loader)
                if !self.hasWaved {
                    self.hasWaved = true
                    self.play(clip: AraClips.wave, on: entity, anim: anim, loop: false)
                    self.onLog?("[ARA] wave greeting")
                    try? await Task.sleep(nanoseconds: UInt64(AraClips.wave.duration * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                }
                // Speaking loop: Talk → TalkExplain → Talk → Talk → TalkExplain ...
                var cycle = 0
                while !Task.isCancelled {
                    let clip = (cycle % 3 == 2) ? AraClips.talkExplain : AraClips.talk
                    self.play(clip: clip, on: entity, anim: anim, loop: false)
                    self.onLog?("[ARA] \(clip.name) (cycle \(cycle))")
                    let wait = clip.duration - 0.25  // blend 0.25s before end
                    try? await Task.sleep(nanoseconds: UInt64(max(0.1, wait) * 1_000_000_000))
                    cycle += 1
                }
            }

        case .happy:
            play(clip: AraClips.laugh, on: entity, anim: anim, loop: false)
            onLog?("[ARA] laugh/happy")
            scheduleReturn(to: .idle, after: AraClips.laugh.duration + 0.3)

        case .surprised:
            play(clip: AraClips.cheer, on: entity, anim: anim, loop: false)
            onLog?("[ARA] cheer/surprised")
            scheduleReturn(to: .idle, after: AraClips.cheer.duration + 0.3)

        case .empathy:
            play(clip: AraClips.empathy, on: entity, anim: anim, loop: false)
            onLog?("[ARA] empathy")
            scheduleReturn(to: .idle, after: AraClips.empathy.duration + 0.3)
        }
    }

    private var hasWaved = false

    private func scheduleReturn(to emotion: AraEmotion, after seconds: Double) {
        speakingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.setEmotion(emotion)
        }
    }

    // MARK: - Clip playback

    private func play(clip: AraClip, on entity: Entity, anim: AnimationResource?, loop: Bool) {
        // Collect all availableAnimations recursively
        func collectAnims(_ e: Entity) -> [AnimationResource] {
            var result = e.availableAnimations
            for child in e.children { result += collectAnims(child) }
            return result
        }
        let all = collectAnims(entity)
        guard clip.index < all.count else {
            onLog?("[ARA ERROR] index \(clip.index) out of range (count=\(all.count)) for \(clip.name)")
            return
        }
        let clip_anim = all[clip.index]
        let final: AnimationResource = loop
            ? clip_anim.repeat(duration: .infinity)
            : clip_anim
        activeController?.stop()
        activeController = entity.playAnimation(final, transitionDuration: 0.25, startsPaused: false)
        onLog?("[ARA] play[\(clip.index)] \(clip.name) loop=\(loop)")
    }

    // MARK: - Load

    func load() {
        guard entity == nil, loadSubscription == nil else { return }
        status = "Đang nạp Ara-Avatar.usdz…"
        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz"
            onLog?("[ARA MODEL] Bundle lookup failed")
            return
        }
        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.loadSubscription = nil
                if case .failure(let error) = completion {
                    self.status = "Lỗi nạp USDZ: \(error.localizedDescription)"
                    self.onLog?("[ARA MODEL] Load failed: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] model in
                guard let self else { return }
                self.loadSubscription = nil

                func countAnims(_ e: Entity) -> Int {
                    e.availableAnimations.count + e.children.reduce(0) { $0 + countAnims($1) }
                }
                let totalAnims = countAnims(model)
                self.globalAnimation = model.availableAnimations.first
                self.onLog?("[ARA ANIM] \(totalAnims) clips ready")

                self.entity = model
                self.status = "Ara sẵn sàng"
                self.onLog?("[ARA MODEL] loaded")

                // Stop autoplay from USDZ, then start Idle
                model.stopAllAnimations()
                self.play(clip: AraClips.idle, on: model, anim: nil, loop: true)
                self.onLog?("[ARA] idle start")
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

    private func attach(_ model: Entity, zoomScale: Float, rotationY: Float, to view: ARView, coordinator: Coordinator) {
        let bounds = model.visualBounds(recursive: true, relativeTo: model)
        let height = bounds.extents.y
        let baseScale: Float = height.isFinite && height > 0 ? 1.6 / height : 1  // full body: scale down vs 1.35
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        // Full body center (not upper-body offset)
        let center = bounds.center
        coordinator.basePosition = -center * baseScale
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

