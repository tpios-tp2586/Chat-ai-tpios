import Combine
import RealityKit
import SwiftUI

struct AraAvatarView: View {
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
                onLog("[ARA VIEW] Zoom saved: \(String(format: "%.2f", savedZoomScale))x")
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
                onLog("[ARA VIEW] Camera rotation: \(String(format: "%.0f", degrees))°")
            }
    }

    var body: some View {
        ZStack {
            if let entity = loader.entity {
                AraRealityView(
                    entity: entity,
                    zoomScale: Float(savedZoomScale),
                    rotationY: rotationY
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
            loader.load()
        }
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

    private var loadSubscription: AnyCancellable?

    private func playGestureReview(on rig: ModelEntity) {
        let requiredIndices = [10, 11, 12, 13, 34, 35, 36, 37]
        let baseline = rig.jointTransforms
        guard baseline.count == rig.jointNames.count,
              requiredIndices.allSatisfy({ $0 < baseline.count }) else {
            onLog?("[ARA ACTION] Invalid rig transform mapping; gestures skipped")
            return
        }

        var current = baseline
        var resources: [AnimationResource] = []

        func appendStep(
            name: String,
            rotations: [Int: simd_quatf],
            duration: TimeInterval
        ) throws {
            let indices = rotations.keys.sorted()
            let from = indices.map { current[$0] }
            let to = indices.map { index -> Transform in
                var transform = current[index]
                transform.rotation = transform.rotation * rotations[index]!
                current[index] = transform
                return transform
            }

            var animation = FromToByAnimation<JointTransforms>()
            animation.name = name
            animation.jointNames = indices.map { rig.jointNames[$0] }
            animation.isScaleAnimated = false
            animation.isRotationAnimated = true
            animation.isTranslationAnimated = false
            animation.fromValue = JointTransforms(from)
            animation.toValue = JointTransforms(to)
            animation.duration = duration
            animation.timing = .easeInOut
            animation.bindTarget = .transform
            animation.fillMode = .forwards
            resources.append(try AnimationResource.generate(with: animation))
        }

        func appendRest(name: String, indices: [Int], duration: TimeInterval) throws {
            let from = indices.map { current[$0] }
            let to = indices.map { baseline[$0] }
            var animation = FromToByAnimation<JointTransforms>()
            animation.name = name
            animation.jointNames = indices.map { rig.jointNames[$0] }
            animation.isScaleAnimated = false
            animation.isRotationAnimated = true
            animation.isTranslationAnimated = false
            animation.fromValue = JointTransforms(from)
            animation.toValue = JointTransforms(to)
            animation.duration = duration
            animation.timing = .easeInOut
            animation.bindTarget = .transform
            animation.fillMode = .forwards
            resources.append(try AnimationResource.generate(with: animation))
            for index in indices { current[index] = baseline[index] }
        }

        func rotation(_ degrees: Float, axis: SIMD3<Float>) -> simd_quatf {
            simd_quatf(angle: degrees * .pi / 180, axis: axis)
        }

        do {
            let rightArm = [34, 35, 36, 37]
            let bothArms = [10, 11, 12, 13, 34, 35, 36, 37]

            // 1. Wave: lift the right arm, move the wrist, then restore the imported pose.
            try appendStep(name: "wave-lift", rotations: [
                34: rotation(-32, axis: [0, 0, 1]),
                35: rotation(-24, axis: [0, 0, 1]),
                36: rotation(18, axis: [0, 0, 1])
            ], duration: 0.85)
            try appendStep(name: "wave-wrist-out", rotations: [
                37: rotation(16, axis: [1, 0, 0])
            ], duration: 0.24)
            try appendStep(name: "wave-wrist-back", rotations: [
                37: rotation(-32, axis: [1, 0, 0])
            ], duration: 0.28)
            try appendStep(name: "wave-wrist-center", rotations: [
                37: rotation(16, axis: [1, 0, 0])
            ], duration: 0.24)
            try appendRest(name: "wave-return", indices: rightArm, duration: 0.75)

            // 2. Explain: one arm comes forward with a clear elbow bend.
            try appendStep(name: "explain-gesture", rotations: [
                34: rotation(-22, axis: [0, 0, 1]),
                35: rotation(-16, axis: [0, 0, 1]),
                36: rotation(38, axis: [0, 0, 1]),
                37: rotation(9, axis: [1, 0, 0])
            ], duration: 0.9)
            try appendRest(name: "explain-return", indices: rightArm, duration: 0.75)

            // 3. Open both arms gently, then return both sides to the exact baseline.
            try appendStep(name: "open-both-arms", rotations: [
                10: rotation(20, axis: [0, 0, 1]),
                11: rotation(18, axis: [0, 0, 1]),
                12: rotation(-12, axis: [0, 0, 1]),
                34: rotation(-20, axis: [0, 0, 1]),
                35: rotation(-18, axis: [0, 0, 1]),
                36: rotation(12, axis: [0, 0, 1])
            ], duration: 1.0)
            try appendRest(name: "open-arms-return", indices: bothArms, duration: 0.85)

            let sequence = try AnimationResource.sequence(with: resources)
            rig.playAnimation(sequence, transitionDuration: 0.2)
            onLog?("[ARA ACTION] Started 3 gestures: wave → explain → open both arms → exact rest pose")
        } catch {
            onLog?("[ARA ACTION] Could not create gesture sequence: \(error.localizedDescription)")
        }
    }

    func load() {
        guard entity == nil, loadSubscription == nil else { return }
        status = "Đang nạp Ara-Avatar.usdz từ app bundle…"

        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz trong app bundle"
            onLog?("[ARA MODEL] Bundle lookup failed: Ara-Avatar.usdz")
            return
        }

        let assetBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        onLog?("[ARA MODEL] Found bundled asset: \(url.lastPathComponent), size=\(assetBytes) bytes")

        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.loadSubscription = nil
                if case .failure(let error) = completion {
                    self.status = "Lỗi nạp Ara-Avatar.usdz: \(error.localizedDescription)"
                    self.onLog?("[ARA MODEL] USDZ load failed: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] model in
                guard let self else { return }
                self.loadSubscription = nil

                let embeddedAnimations = model.availableAnimations
                let names = embeddedAnimations.compactMap(\.name).joined(separator: ", ")
                self.onLog?("[ARA MODEL] Embedded animation resources=\(embeddedAnimations.count); playback is disabled")
                if !names.isEmpty {
                    self.onLog?("[ARA MODEL] Embedded animation names (not used by gesture review): \(names)")
                }

                var rigCount = 0
                var actionRig: ModelEntity?
                let inspectedJointNames: Set<String> = [
                    "Spine", "Spine1", "Spine2", "Neck",
                    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
                    "RightShoulder", "RightArm", "RightForeArm", "RightHand"
                ]
                let rigLog = self.onLog
                func inspectRig(_ candidate: Entity) {
                    if let rig = candidate as? ModelEntity, !rig.jointNames.isEmpty {
                        rigCount += 1
                        if actionRig == nil { actionRig = rig }
                        let joints = rig.jointNames
                        let transforms = rig.jointTransforms
                        let upperBody = joints.enumerated().compactMap { index, path in
                            let name = path.split(separator: "/").last.map(String.init) ?? path
                            return inspectedJointNames.contains(name) ? "\(index):\(name)" : nil
                        }
                        rigLog?("[ARA RIG] model=\(rigCount - 1) name=\(rig.name) joints=\(joints.count) transforms=\(transforms.count)")
                        rigLog?("[ARA RIG] upper-body matches: \(upperBody.isEmpty ? "none" : upperBody.joined(separator: ", "))")
                        for index in [1, 2, 3, 10, 11, 12, 13, 34, 35, 36, 37] where index < joints.count && index < transforms.count {
                            let transform = transforms[index]
                            let position = transform.translation
                            let rotation = transform.rotation.vector
                            let scale = transform.scale
                            let name = joints[index].split(separator: "/").last.map(String.init) ?? joints[index]
                            rigLog?("[ARA RIG] rest[\(index)] \(name) t=(\(position.x),\(position.y),\(position.z)) q=(\(rotation.x),\(rotation.y),\(rotation.z),\(rotation.w)) s=(\(scale.x),\(scale.y),\(scale.z))")
                        }
                        let indexedJointNames = joints.enumerated().map { "\($0.offset):\($0.element)" }
                        for start in stride(from: 0, to: indexedJointNames.count, by: 12) {
                            let end = min(start + 12, indexedJointNames.count)
                            rigLog?("[ARA RIG] joints[\(start)-\(end - 1)]: \(indexedJointNames[start..<end].joined(separator: " | "))")
                        }
                    }
                    candidate.children.forEach(inspectRig)
                }
                inspectRig(model)
                if rigCount == 0 {
                    self.onLog?("[ARA RIG] No imported ModelEntity exposes jointNames; movement review skipped")
                }

                self.entity = model
                self.status = "Ara đã tải — đang kiểm tra 3 cử chỉ thân trên"
                if let rig = actionRig {
                    playGestureReview(on: rig)
                }
                self.onLog?("[ARA ACTION] Model mounted; one-time upper-body gesture review requested")
            })
    }
}

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

        // Keep the existing upper-body framing while the model itself stays in its imported static pose.
        let upperBodyCenter = SIMD3<Float>(
            bounds.center.x,
            bounds.center.y + height * 0.27,
            bounds.center.z
        )
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