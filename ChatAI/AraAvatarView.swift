import Combine
import RealityKit
import SwiftUI

// MARK: - Emotion

enum AraEmotion: Equatable {
    case idle, speaking, happy, thinking, empathy, surprised
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
    private var activeRig: ModelEntity?
    private var restTransforms: [Transform]?
    private var activeController: AnimationPlaybackController?
    private var currentEmotion: AraEmotion = .idle

    // MARK: Emotion dispatch

    func setEmotion(_ emotion: AraEmotion) {
        guard emotion != currentEmotion else { return }
        currentEmotion = emotion
        guard let rig = activeRig, let baseline = restTransforms else { return }
        playEmotion(emotion, on: rig, baseline: baseline)
    }

    private func playEmotion(_ emotion: AraEmotion, on rig: ModelEntity, baseline: [Transform]) {
        activeController?.stop()
        activeController = nil

        switch emotion {
        case .idle:
            returnToRest(on: rig, baseline: baseline, indices: [10,11,12,13,34,35,36,37])

        case .speaking:
            // Right arm gentle raise-lower loop
            activeController = buildLoop(on: rig, baseline: baseline,
                pose: poseWith(baseline, deltas: [
                    34: rot(-18, [0,0,1]), 35: rot(-12, [0,0,1]),
                    36: rot(24,  [0,0,1]), 37: rot(7,   [1,0,0])
                ]),
                indices: [34,35,36,37], raiseDur: 1.05, lowerDur: 1.0)
            onLog?("[ARA] speaking gesture")

        case .happy:
            // Both arms open outward, hold 1.8s, return
            activeController = buildHold(on: rig, baseline: baseline,
                pose: poseWith(baseline, deltas: [
                    10: rot(22,  [0,0,1]), 11: rot(18,  [0,0,1]), 12: rot(-10, [0,0,1]),
                    34: rot(-22, [0,0,1]), 35: rot(-18, [0,0,1]), 36: rot(10,  [0,0,1])
                ]),
                indices: [10,11,12,13,34,35,36,37], raiseDur: 0.55, holdDur: 1.8, lowerDur: 0.65)
            onLog?("[ARA] happy gesture")

        case .thinking:
            // Right arm raises high, elbow bent toward chin
            activeController = buildHold(on: rig, baseline: baseline,
                pose: poseWith(baseline, deltas: [
                    34: rot(-28, [0,0,1]), 35: rot(-20, [0,0,1]),
                    36: rot(55,  [0,0,1]), 37: rot(-15, [1,0,0])
                ]),
                indices: [34,35,36,37], raiseDur: 0.7, holdDur: 2.4, lowerDur: 0.65)
            onLog?("[ARA] thinking gesture")

        case .empathy:
            // Left arm crosses toward chest
            activeController = buildHold(on: rig, baseline: baseline,
                pose: poseWith(baseline, deltas: [
                    10: rot(-22, [0,0,1]), 11: rot(-28, [0,0,1]), 12: rot(18, [0,0,1])
                ]),
                indices: [10,11,12,13], raiseDur: 0.6, holdDur: 2.0, lowerDur: 0.65)
            onLog?("[ARA] empathy gesture")

        case .surprised:
            // Both arms fan out quickly, return
            activeController = buildHold(on: rig, baseline: baseline,
                pose: poseWith(baseline, deltas: [
                    10: rot(32,  [0,0,1]), 11: rot(26,  [0,0,1]),
                    34: rot(-32, [0,0,1]), 35: rot(-26, [0,0,1])
                ]),
                indices: [10,11,12,13,34,35,36,37], raiseDur: 0.28, holdDur: 0.9, lowerDur: 0.55)
            onLog?("[ARA] surprised gesture")
        }
    }

    // MARK: Helpers

    private func rot(_ deg: Float, _ axis: SIMD3<Float>) -> simd_quatf {
        simd_quatf(angle: deg * .pi / 180, axis: axis)
    }

    private func poseWith(_ baseline: [Transform], deltas: [Int: simd_quatf]) -> [Int: Transform] {
        var out: [Int: Transform] = [:]
        for (i, q) in deltas {
            var t = baseline[i]
            t.rotation = t.rotation * q
            out[i] = t
        }
        return out
    }

    // Single raise → lower loop (for speaking)
    private func buildLoop(
        on rig: ModelEntity, baseline: [Transform],
        pose: [Int: Transform], indices: [Int],
        raiseDur: Double, lowerDur: Double
    ) -> AnimationPlaybackController? {
        let names = indices.map { rig.jointNames[$0] }
        let from  = JointTransforms(indices.map { baseline[$0] })
        let to    = JointTransforms(indices.map { pose[$0] ?? baseline[$0] })
        do {
            var up = FromToByAnimation<JointTransforms>()
            up.jointNames = names; up.fromValue = from; up.toValue = to
            up.duration = raiseDur; up.timing = .easeInOut
            up.bindTarget = .jointTransforms; up.fillMode = .forwards
            up.isScaleAnimated = false

            var dn = FromToByAnimation<JointTransforms>()
            dn.jointNames = names; dn.fromValue = to; dn.toValue = from
            dn.duration = lowerDur; dn.timing = .easeInOut
            dn.bindTarget = .jointTransforms; dn.fillMode = .forwards
            dn.isScaleAnimated = false

            let cycle = try AnimationResource.sequence(with: [
                AnimationResource.generate(with: up),
                AnimationResource.generate(with: dn)
            ]).repeat(duration: .infinity)
            return rig.playAnimation(cycle, transitionDuration: 0.35)
        } catch { return nil }
    }

    // Raise → hold → lower (for all other emotions)
    private func buildHold(
        on rig: ModelEntity, baseline: [Transform],
        pose: [Int: Transform], indices: [Int],
        raiseDur: Double, holdDur: Double, lowerDur: Double
    ) -> AnimationPlaybackController? {
        let names = indices.map { rig.jointNames[$0] }
        let from  = JointTransforms(indices.map { baseline[$0] })
        let to    = JointTransforms(indices.map { pose[$0] ?? baseline[$0] })
        do {
            var up = FromToByAnimation<JointTransforms>()
            up.jointNames = names; up.fromValue = from; up.toValue = to
            up.duration = raiseDur; up.timing = .easeOut
            up.bindTarget = .jointTransforms; up.fillMode = .forwards
            up.isScaleAnimated = false

            var hold = FromToByAnimation<JointTransforms>()
            hold.jointNames = names; hold.fromValue = to; hold.toValue = to
            hold.duration = holdDur; hold.timing = .linear
            hold.bindTarget = .jointTransforms; hold.fillMode = .forwards
            hold.isScaleAnimated = false

            var dn = FromToByAnimation<JointTransforms>()
            dn.jointNames = names; dn.fromValue = to; dn.toValue = from
            dn.duration = lowerDur; dn.timing = .easeIn
            dn.bindTarget = .jointTransforms; dn.fillMode = .forwards
            dn.isScaleAnimated = false

            let seq = try AnimationResource.sequence(with: [
                AnimationResource.generate(with: up),
                AnimationResource.generate(with: hold),
                AnimationResource.generate(with: dn)
            ])
            return rig.playAnimation(seq, transitionDuration: 0.25)
        } catch { return nil }
    }

    private func returnToRest(on rig: ModelEntity, baseline: [Transform], indices: [Int]) {
        let names = indices.map { rig.jointNames[$0] }
        let current = rig.jointTransforms
        let from = JointTransforms(indices.map { current[$0] })
        let to   = JointTransforms(indices.map { baseline[$0] })
        do {
            var anim = FromToByAnimation<JointTransforms>()
            anim.jointNames = names; anim.fromValue = from; anim.toValue = to
            anim.duration = 0.55; anim.timing = .easeInOut
            anim.bindTarget = .jointTransforms; anim.fillMode = .forwards
            anim.isScaleAnimated = false
            activeController = rig.playAnimation(try AnimationResource.generate(with: anim), transitionDuration: 0.2)
        } catch {
            rig.jointTransforms = baseline
        }
    }

    // MARK: Load

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

                // Find rig (first ModelEntity with jointNames)
                var found: ModelEntity?
                func findRig(_ e: Entity) {
                    if found == nil, let m = e as? ModelEntity, !m.jointNames.isEmpty { found = m }
                    if found == nil { e.children.forEach(findRig) }
                }
                findRig(model)

                self.entity = model
                if let rig = found {
                    self.activeRig = rig
                    self.restTransforms = rig.jointTransforms
                    self.status = "Ara sẵn sàng"
                    self.onLog?("[ARA RIG] joints=\(rig.jointNames.count)")
                } else {
                    self.status = "Ara loaded (no rig)"
                    self.onLog?("[ARA RIG] No rig found")
                }
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
            if context.coordinator.currentZoom != zoomScale { applyZoom(zoomScale, to: entity, coordinator: context.coordinator) }
            if context.coordinator.currentRotationY != rotationY { applyRotation(rotationY, coordinator: context.coordinator) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func attach(_ model: Entity, zoomScale: Float, rotationY: Float, to view: ARView, coordinator: Coordinator) {
        let bounds = model.visualBounds(recursive: true, relativeTo: model)
        let height = bounds.extents.y
        let baseScale: Float = height.isFinite && height > 0 ? 1.35 / height : 1
        coordinator.baseScale = SIMD3<Float>(repeating: baseScale)
        let upperBodyCenter = SIMD3<Float>(bounds.center.x, bounds.center.y + height * 0.27, bounds.center.z)
        coordinator.basePosition = -upperBodyCenter * baseScale
        coordinator.currentEntity = model
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.4))
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
