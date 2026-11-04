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

    func load() {
        guard entity == nil, loadSubscription == nil else { return }
        status = "Đang nạp Ara-Avatar.usdz từ app bundle…"

        guard let url = Bundle.main.url(forResource: "Ara-Avatar", withExtension: "usdz") else {
            status = "Không tìm thấy Ara-Avatar.usdz trong app bundle"
            onLog?("[ARA STATIC] Bundle lookup failed: Ara-Avatar.usdz")
            return
        }

        let assetBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        onLog?("[ARA STATIC] Found bundled asset: \(url.lastPathComponent), size=\(assetBytes) bytes")

        loadSubscription = Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.loadSubscription = nil
                if case .failure(let error) = completion {
                    self.status = "Lỗi nạp Ara-Avatar.usdz: \(error.localizedDescription)"
                    self.onLog?("[ARA STATIC] USDZ load failed: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] model in
                guard let self else { return }
                self.loadSubscription = nil

                let embeddedAnimations = model.availableAnimations
                let names = embeddedAnimations.compactMap(\.name).joined(separator: ", ")
                self.onLog?("[ARA STATIC] Embedded animation resources=\(embeddedAnimations.count); playback is disabled")
                if !names.isEmpty {
                    self.onLog?("[ARA STATIC] Asset animation names (not played): \(names)")
                }

                var rigCount = 0
                let inspectedJointNames: Set<String> = [
                    "Spine", "Spine1", "Spine2", "Neck",
                    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
                    "RightShoulder", "RightArm", "RightForeArm", "RightHand"
                ]
                func inspectRig(_ candidate: Entity) {
                    if let rig = candidate as? ModelEntity, !rig.jointNames.isEmpty {
                        rigCount += 1
                        let joints = rig.jointNames
                        let transforms = rig.jointTransforms
                        let upperBody = joints.enumerated().compactMap { index, name in
                            inspectedJointNames.contains(name) ? "\(index):\(name)" : nil
                        }
                        self.onLog?("[ARA RIG] model=\(rigCount - 1) name=\(rig.name) joints=\(joints.count) transforms=\(transforms.count)")
                        self.onLog?("[ARA RIG] upper-body joint indices: \(upperBody.joined(separator: ", "))")
                    }
                    candidate.children.forEach(inspectRig)
                }
                inspectRig(model)
                if rigCount == 0 {
                    self.onLog?("[ARA RIG] No imported ModelEntity exposes jointNames; stop before adding movement")
                }

                self.entity = model
                self.status = "Ara đã tải — chế độ đứng yên"
                self.onLog?("[ARA STATIC] Model mounted in its imported pose; animation generation and playback are not present in the app")
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