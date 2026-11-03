import Combine
import RealityKit
import SwiftUI

struct AraAvatarView: View {
    enum Clip: String {
        case idle = "Idle"
        case wave = "Wave"
        case talk = "Talk"
        case talkExplain = "TalkExplain"
        case listening = "AraListening"
        case thinking = "AraThinking"
        case empathy = "AraEmpathy"
        case laugh = "AraLaugh"
        case cheer = "Cheer"
        case naturalLaugh = "Laugh"
        case cry = "Cry"
        case walk = "Walk"
        case run = "Run"
        case walkBackwards = "Walk backwards"
        case strafeLeft = "Strafe left"
        case strafeRight = "Strafe right"
        case jumpStart = "Jump start"
        case jumpAir = "Jump (in air)"
        case jumpLand = "Jump land"
        case sitDown = "Sit down (chair)"
        case sitIdle = "Sit idle (chair)"
        case standUp = "Stand up (chair)"
        case lieDown = "Lie down"
        case sleep = "Sleep"
        case turnLeft45 = "Turn left 45°"
        case turnLeft90 = "Turn left 90°"
        case turnRight45 = "Turn right 45°"
        case turnRight90 = "Turn right 90°"
        case fullTurn = "Full turn 360°"
        case rideHorse = "Ride horse (trot)"

        var loops: Bool {
            switch self {
            case .idle, .talk, .listening, .thinking, .empathy, .walk, .run,
                 .walkBackwards, .strafeLeft, .strafeRight, .sitIdle, .sleep, .rideHorse:
                return true
            default:
                return false
            }
        }
    }

    let clip: Clip
    let resetToFrontToken: Int
    let repeatForTesting: Bool
    let onLog: (String) -> Void
    @StateObject private var loader = AraAvatarLoader()
    @AppStorage("ara_avatar_zoom_scale_v3") private var savedZoomScale = 2.5
    @State private var pinchStartScale = 1.0
    @State private var rotationY: Float = 0
    @State private var dragStartRotation: Float = 0

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

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let radiansPerPoint = Float.pi / 360
                rotationY = dragStartRotation + Float(value.translation.width) * radiansPerPoint
            }
            .onEnded { _ in
                dragStartRotation = rotationY
                let degrees = rotationY * 180 / Float.pi
                onLog("[ARA] User rotation: \(String(format: "%.0f", degrees))°")
            }
    }

    var body: some View {
        ZStack {
            if let entity = loader.entity {
                AraRealityView(
                    entity: entity,
                    zoomScale: Float(savedZoomScale),
                    rotationY: rotationY,
                    clip: clip
                )
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
            let info = Bundle.main.infoDictionary
            let sourceCommit = info?["ChatAISourceCommit"] as? String ?? "unknown"
            let buildNumber = info?["ChatAIBuildNumber"] as? String ?? "unknown"
            onLog("[BUILD] source=\(sourceCommit.prefix(12)) build=\(buildNumber)")
            loader.show(clip, repeatForTesting: repeatForTesting)
        }
        .onChange(of: clip) { newClip in
            loader.show(newClip, repeatForTesting: repeatForTesting)
        }
        .onChange(of: repeatForTesting) { isTesting in
            loader.show(clip, repeatForTesting: isTesting)
        }
        .onChange(of: resetToFrontToken) { _ in
            guard abs(rotationY) > 0.001 else { return }
            rotationY = 0
            dragStartRotation = 0
            onLog("[ARA] Reset to front at AI speech start")
        }
        .onReceive(loader.$status.dropFirst()) { status in
            onLog("[ARA] \(status)")
        }
    }
}

private struct AraAnimationTimeline: Decodable {
    let clips: [AraAnimationClipRange]
}

private struct AraAnimationClipRange: Decodable {
    let name: String
    let start: TimeInterval
    let end: TimeInterval
}

@MainActor
private final class AraAvatarLoader: ObservableObject {
    @Published var entity: Entity?
    @Published var status = "Đang nạp avatar Ara…"
    var onLog: ((String) -> Void)?

    private var requestedClip: AraAvatarView.Clip?
    private var requestedRepeatForTesting = false
    private var activeClip: AraAvatarView.Clip?
    private var activeRepeatForTesting = false
    private var animations: [String: AnimationResource] = [:]
    private var loadSubscription: AnyCancellable?
    private var playback: AnimationPlaybackController?

    func show(_ clip: AraAvatarView.Clip, repeatForTesting: Bool = false) {
        requestedClip = clip
        requestedRepeatForTesting = repeatForTesting
        guard let entity else {
            guard loadSubscription == nil else { return }
            load()
            return
        }
        guard activeClip != clip || activeRepeatForTesting != repeatForTesting else { return }
        play(clip, on: entity, repeatForTesting: repeatForTesting)
    }

    private func load() {
        status = "Đang nạp Ara-Avatar.usdz từ app bundle…"
        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz trong app bundle"
            onLog?("[ARA] Bundle lookup failed: Ara-Avatar.usdz")
            return
        }
        let assetBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        onLog?("[ARA] Found bundled asset: \(url.lastPathComponent), size=\(assetBytes) bytes")

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
                self.loadSubscription = nil

                let imported = model.availableAnimations
                let importedNames = imported.compactMap(\.name).joined(separator: ", ")
                self.onLog?("[ARA] Imported source animations (\(imported.count)): \(importedNames)")

                guard let source = imported.first else {
                    self.status = "USDZ không có animation nguồn"
                    self.onLog?("[ARA] No AnimationResource found on the imported model")
                    return
                }

                guard
                    let timelineURL = Bundle.main.url(forResource: "animation-timeline", withExtension: "json"),
                    let timelineData = try? Data(contentsOf: timelineURL),
                    let timeline = try? JSONDecoder().decode(AraAnimationTimeline.self, from: timelineData)
                else {
                    self.status = "Không tìm thấy animation-timeline.json trong app bundle"
                    self.onLog?("[ARA] Timeline manifest missing or invalid")
                    return
                }

                let requiredDuration = timeline.clips.map(\.end).max() ?? 0
                let sourceDuration = source.definition.duration
                let ranges = timeline.clips.map { "\($0.name)(\(String(format: "%.2f", $0.start))-\(String(format: "%.2f", $0.end))s)" }.joined(separator: ", ")
                self.onLog?("[ARA] Manifest: \(timeline.clips.count) clips [\(ranges)]; duration=\(String(format: "%.2f", requiredDuration))s; USDZ=\(String(format: "%.2f", sourceDuration))s; JSON=\(timelineData.count) bytes")
                guard sourceDuration + 0.01 >= requiredDuration else {
                    self.status = "Timeline USDZ ngắn hơn manifest"
                    self.onLog?("[ARA] Timeline duration mismatch: USDZ \(sourceDuration)s; manifest \(requiredDuration)s")
                    return
                }

                var clips: [String: AnimationResource] = [:]
                do {
                    for range in timeline.clips {
                        let view = AnimationView(
                            source: source.definition,
                            name: range.name,
                            trimStart: range.start,
                            trimEnd: range.end
                        )
                        clips[range.name.lowercased()] = try AnimationResource.generate(with: view)
                    }
                } catch {
                    self.status = "Không tạo được các clip animation Ara"
                    self.onLog?("[ARA] AnimationView generation failed: \(error.localizedDescription)")
                    return
                }

                let requiredNames = ["idle", "wave", "talk", "talkexplain", "aralistening", "arathinking", "araempathy", "aralaugh"]
                let missing = requiredNames.filter { clips[$0] == nil }
                guard missing.isEmpty else {
                    self.status = "Thiếu clip animation: \(missing.joined(separator: ", "))"
                    self.onLog?("[ARA] Timeline manifest missing clips: \(missing.joined(separator: ", "))")
                    return
                }

                self.animations = clips

                self.entity = model
                let clipSummary = timeline.clips.map {
                    "\($0.name)(\(String(format: "%.2f", $0.start))-\(String(format: "%.2f", $0.end))s)"
                }.joined(separator: ", ")
                self.onLog?("[ARA] Built \(clips.count) AnimationViews from \(source.name ?? "unnamed source"); source duration \(String(format: "%.2f", sourceDuration))s; \(clipSummary)")

                guard let clip = self.requestedClip else { return }
                self.play(clip, on: model, repeatForTesting: self.requestedRepeatForTesting)
            })
    }

    private func play(_ clip: AraAvatarView.Clip, on model: Entity, repeatForTesting: Bool) {
        guard let animation = animations[clip.rawValue.lowercased()] else {
            status = "Không tìm thấy animation \(clip.rawValue) trong timeline Ara"
            onLog?("[ARA] Missing generated clip: \(clip.rawValue); available: \(animations.keys.sorted().joined(separator: ", "))")
            return
        }

        if let previousPlayback = playback {
            if previousPlayback.isValid {
                onLog?("[ARA] Replacing playback: clip=\(activeClip?.rawValue ?? "unknown"), playing=\(previousPlayback.isPlaying), time=\(String(format: "%.2f", previousPlayback.time))/\(String(format: "%.2f", previousPlayback.duration))s")
                previousPlayback.stop()
                onLog?("[ARA] Previous playback stopped: stopped=\(previousPlayback.isStopped), playing=\(previousPlayback.isPlaying)")
            } else {
                onLog?("[ARA] Previous playback already inactive: clip=\(activeClip?.rawValue ?? "unknown")")
            }
        }

        let nextPlayback = model.playAnimation(
            clip.loops ? animation.repeat() : animation,
            transitionDuration: 0.25
        )
        playback = nextPlayback
        activeClip = clip
        activeRepeatForTesting = repeatForTesting
        status = "Đang phát animation \(clip.rawValue)"
        onLog?("[ARA] Playback started: clip=\(clip.rawValue), playing=\(nextPlayback.isPlaying), valid=\(nextPlayback.isValid), duration=\(String(format: "%.2f", nextPlayback.duration))s")
    }
}

private struct AraRealityView: UIViewRepresentable {
    let entity: Entity
    let zoomScale: Float
    let rotationY: Float
    let clip: AraAvatarView.Clip

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
            if context.coordinator.currentClip != clip {
                context.coordinator.currentClip = clip
                if clip != .idle {
                    context.coordinator.motionRoot?.orientation = simd_quatf()
                }
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
        let bounds = model.visualBounds(recursive: true, relativeTo: model)
        let height = bounds.extents.y
        let baseScale: Float = height.isFinite && height > 0 ? 1.35 / height : 1
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)

        // GLB skin-weight analysis places the head, torso and both arms around 77% of full height.
        // Recenter the view for the upper-body test without removing or modifying the lower-body rig.
        let upperBodyCenter = SIMD3<Float>(
            bounds.center.x,
            bounds.center.y + height * 0.27,
            bounds.center.z
        )
        coordinator.basePosition = -upperBodyCenter * baseScale
        coordinator.currentEntity = model
        coordinator.currentClip = clip

        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.4))
        let motionRoot = Entity()
        anchor.addChild(motionRoot)
        motionRoot.addChild(model)
        coordinator.rotationPivot = anchor
        coordinator.motionRoot = motionRoot
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
        var motionRoot: Entity?
        var baseScale = SIMD3<Float>(repeating: 1)
        var basePosition = SIMD3<Float>(repeating: 0)
        var currentZoom: Float = 1
        var currentRotationY: Float = 0
        var currentClip: AraAvatarView.Clip = .idle
    }
}
