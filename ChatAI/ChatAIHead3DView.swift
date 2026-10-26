import SwiftUI
import RealityKit
import SceneKit
import UIKit
import Combine

/// Loads the USDZ generated from the uploaded GLB during CI. If RealityKit cannot load it,
/// a visible SwiftUI robot remains on screen instead of leaving an empty dark rectangle.
struct ChatAIHead3DView: View {
    var headRotation: Float = 0
    var speaking: Bool = false

    @State private var modelLoaded = false
    @State private var loadMessage = "Đang tải mô hình 3D…"
    @State private var copyStatus = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.04, blue: 0.075), Color(red: 0.10, green: 0.035, blue: 0.14)], startPoint: .top, endPoint: .bottom)

            FallbackCompanionRobot(speaking: speaking)
                .padding(.vertical, 8)
                .opacity(modelLoaded ? 0 : 1)

            CompanionRealityView(headRotation: headRotation, speaking: speaking) { success, message in
                modelLoaded = success
                loadMessage = message
            }
            .opacity(modelLoaded ? 1 : 0)
            .allowsHitTesting(modelLoaded)
            .accessibilityHidden(!modelLoaded)

            if !modelLoaded {
                VStack {
                    Spacer()
                    Text(loadMessage)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.bottom, 6)
                }
            } else {
                VStack {
                    Spacer()
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Button {
                                UIPasteboard.general.string = loadMessage
                                copyStatus = "Đã copy log"
                            } label: {
                                Label("Copy log", systemImage: "doc.on.doc")
                                    .font(.caption2.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(.cyan)

                            Button {
                                loadMessage = "Đã xoá log"
                                copyStatus = ""
                            } label: {
                                Label("Xoá", systemImage: "trash")
                                    .font(.caption2.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(.pink)

                            if !copyStatus.isEmpty {
                                Text(copyStatus)
                                    .font(.caption2)
                                    .foregroundStyle(.green.opacity(0.9))
                                    .lineLimit(1)
                            }
                        }

                        ScrollView {
                            Text(loadMessage)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 112)
                        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .onAppear { modelLoaded = false }
    }
}

private struct CompanionRealityView: UIViewRepresentable {
    let headRotation: Float
    let speaking: Bool
    let onResult: (Bool, String) -> Void
    private let modelResourceName = "model-1792924579279"

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.cameraMode = .nonAR
        view.environment.background = .color(UIColor(red: 0.025, green: 0.04, blue: 0.075, alpha: 1))
        let scene = AnchorEntity(world: .zero)
        view.scene.addAnchor(scene)
        let camera = PerspectiveCamera()
        camera.position = [0, 0.02, 1.75]
        camera.look(at: [0, 0, 0], from: camera.position, relativeTo: nil)
        scene.addChild(camera)
        scene.addChild(makeLight(color: .white, intensity: 1300, position: [-0.45, 0.55, 0.65]))
        scene.addChild(makeLight(color: UIColor(red: 0.25, green: 0.7, blue: 1, alpha: 1), intensity: 800, position: [0.5, 0.15, 0.4]))
        scene.addChild(makeLight(color: .white, intensity: 1000, position: [0, 0.45, -0.4]))
        let bundle = Bundle.main
        let directURL = bundle.url(forResource: modelResourceName, withExtension: "usdz") ?? bundle.url(forResource: modelResourceName, withExtension: "usdz", subdirectory: "Companion")
        guard let url = directURL else {
            let resourceRoot = bundle.resourceURL
            let bundledFileExists = resourceRoot?.appendingPathComponent("\(modelResourceName).usdz").path
            let detail = bundledFileExists.map { "Đã kiểm tra: \($0)" } ?? "Không đọc được thư mục tài nguyên ứng dụng."
            DispatchQueue.main.async { onResult(false, "Không tìm thấy USDZ trong app bundle. \(detail)") }
            return view
        }
        do {
            let model = try Entity.load(contentsOf: url)
            model.name = "ChatAICompanionGLB"
            let bounds = model.visualBounds(relativeTo: model)
            let extents = bounds.extents
            let largestDimension = max(extents.x, max(extents.y, extents.z))
            guard largestDimension.isFinite, largestDimension > 0 else {
                throw NSError(domain: "ChatAICompanion", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mô hình GLB không có kích thước hiển thị hợp lệ."])
            }
            let normalizedScale: Float = 1.55 / largestDimension
            model.scale = SIMD3<Float>(repeating: normalizedScale)
            let upAxisCorrection = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            let uprightCorrection = simd_quatf(angle: .pi, axis: [0, 0, 1])
            let axisCorrection = uprightCorrection * upAxisCorrection
            model.orientation = axisCorrection
            model.position = -(axisCorrection.act(bounds.center) * normalizedScale)
            scene.addChild(model)
            context.coordinator.baseOrientation = axisCorrection
            context.coordinator.head = model
            context.coordinator.basePosition = model.position
            let animations = Self.collectAnimations(from: model)
            let rigDetails = Self.inspectSceneKitRig(url: url)
            Self.dumpModelStructure(from: model, resourceURL: url, animationCount: animations.count)
            if let animation = animations.first {
                context.coordinator.authoredAnimation = model.playAnimation(animation.repeat(duration: .infinity), transitionDuration: 0.25, startsPaused: false)
            }
            context.coordinator.jaw = Self.findMouthControl(in: model)
            if let jaw = context.coordinator.jaw { context.coordinator.jawBaseTransform = jaw.transform }
            context.coordinator.animationSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator = context.coordinator] event in
                guard let coordinator, let animatedHead = coordinator.head else { return }
                coordinator.elapsed += Float(event.deltaTime)
                let bob = sin(coordinator.elapsed * 1.8) * 0.025
                animatedHead.position = coordinator.basePosition + SIMD3<Float>(0, bob, 0)
                let yaw = simd_quatf(angle: coordinator.currentHeadRotation, axis: [0, 1, 0])
                animatedHead.transform.rotation = yaw * coordinator.baseOrientation
                coordinator.updateJaw(deltaTime: Float(event.deltaTime))
            }
            DispatchQueue.main.async {
                let mouthStatus = context.coordinator.jaw == nil ? "KHÔNG TÌM THẤY jaw/mouth node theo tên" : "ĐÃ TÌM THẤY jaw/mouth node: \(context.coordinator.jaw?.name ?? "<unnamed>")"
                let animationStatus = animations.isEmpty ? "animations=0" : "animations=\(animations.count)"
                let entityLines = Self.collectEntityDiagnostics(from: model)
                let diagnostic = "[ChatAI-RIG-DIAGNOSTIC] resource=\(url.lastPathComponent)\n\(animationStatus)\n\(mouthStatus)\n\(rigDetails)\nENTITIES:\n\(entityLines)"
                onResult(true, diagnostic)
            }
        } catch {
            DispatchQueue.main.async { onResult(false, "Không tải được USDZ: \(error.localizedDescription)") }
        }
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard let head = context.coordinator.head else { return }
        context.coordinator.currentHeadRotation = headRotation
        context.coordinator.speaking = speaking
        let yaw = simd_quatf(angle: headRotation, axis: [0, 1, 0])
        head.transform.rotation = yaw * context.coordinator.baseOrientation
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var head: Entity?
        var jaw: Entity?
        var jawBaseTransform = Transform()
        var baseOrientation = simd_quatf()
        var basePosition = SIMD3<Float>(repeating: 0)
        var currentHeadRotation: Float = 0
        var elapsed: Float = 0
        var jawPhase: Float = 0
        var speaking = false
        var animationSubscription: (any Cancellable)?
        var authoredAnimation: AnimationPlaybackController?
        weak var view: ARView?

        func updateJaw(deltaTime: Float) {
            guard let jaw else { return }
            if speaking {
                jawPhase += deltaTime * 12.0
                let pulse = max(0, sin(jawPhase) * 0.5 + sin(jawPhase * 1.73) * 0.25)
                let amount = 0.055 * pulse
                let rotation = simd_quatf(angle: amount, axis: [1, 0, 0])
                jaw.transform.rotation = rotation * jawBaseTransform.rotation
            } else {
                jaw.transform.rotation = jawBaseTransform.rotation
            }
        }
    }

    private static func collectAnimations(from entity: Entity) -> [AnimationResource] {
        var result = entity.availableAnimations
        for child in entity.children { result.append(contentsOf: collectAnimations(from: child)) }
        return result
    }

    private static func collectEntityDiagnostics(from root: Entity) -> String {
        var lines: [String] = []
        var visited = 0
        var modelEntityCount = 0
        var animatedEntityCount = 0
        func walk(_ entity: Entity, depth: Int) {
            visited += 1
            let hasModel = entity.components[ModelComponent.self] != nil
            if hasModel { modelEntityCount += 1 }
            let animationCount = entity.availableAnimations.count
            if animationCount > 0 { animatedEntityCount += 1 }
            guard lines.count < 40 else { return }
            let indent = String(repeating: "  ", count: min(depth, 6))
            let name = entity.name.isEmpty ? "<unnamed>" : entity.name
            let kind = String(describing: type(of: entity))
            let components = String(describing: entity.components).replacingOccurrences(of: "\n", with: " ")
            lines.append("\(indent)• \(name) | type=\(kind) | model=\(hasModel ? "YES" : "no") | animations=\(animationCount)")
            lines.append("\(indent)  components: \(components)")
            for child in entity.children {
                walk(child, depth: depth + 1)
                if lines.count >= 40 { break }
            }
        }
        walk(root, depth: 0)
        let summary = "SUMMARY: entities=\(visited), ModelComponent=\(modelEntityCount), entitiesWithAnimations=\(animatedEntityCount)"
        if lines.count >= 40 { lines.append("… danh sách chẩn đoán giới hạn ở 40 dòng") }
        return ([summary] + lines).joined(separator: "\n")
    }

    private static func inspectSceneKitRig(url: URL) -> String {
        let scene: SCNScene
        do {
            scene = try SCNScene(url: url, options: nil)
        } catch {
            return "SCENEKIT_RIG: không đọc được USDZ bằng SceneKit: \(error.localizedDescription)"
        }

        var skinnerNodes = 0
        var boneNames: [String] = []
        var morpherNodes = 0
        var morphNames: [String] = []
        var geometryNodes = 0
        var sceneAnimationCount = 0

        func walk(_ node: SCNNode) {
            if node.geometry != nil { geometryNodes += 1 }
            if let skinner = node.skinner {
                skinnerNodes += 1
                for bone in skinner.bones {
                    if let name = bone.name, !name.isEmpty { boneNames.append(name) }
                }
            }
            if let morpher = node.morpher {
                morpherNodes += 1
                for target in morpher.targets {
                    if let name = target.name, !name.isEmpty { morphNames.append(name) }
                }
            }
            sceneAnimationCount += node.animationKeys.count
            for child in node.childNodes { walk(child) }
        }

        walk(scene.rootNode)
        boneNames = Array(NSOrderedSet(array: boneNames)) as? [String] ?? boneNames
        morphNames = Array(NSOrderedSet(array: morphNames)) as? [String] ?? morphNames

        var lines = [
            "SCENEKIT_RIG: geometryNodes=\(geometryNodes), skinnerNodes=\(skinnerNodes), morpherNodes=\(morpherNodes), animations=\(sceneAnimationCount)"
        ]
        if boneNames.isEmpty {
            lines.append("BONES: none")
        } else {
            lines.append("BONES(\(boneNames.count)): \(boneNames.prefix(120).joined(separator: ", "))")
        }
        if morphNames.isEmpty {
            lines.append("MORPHS: none")
        } else {
            lines.append("MORPHS(\(morphNames.count)): \(morphNames.prefix(120).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private static func dumpModelStructure(from entity: Entity, resourceURL: URL, animationCount: Int) {
        print("[ChatAI-RIG-DIAGNOSTIC] resource=\(resourceURL.lastPathComponent)")
        print("[ChatAI-RIG-DIAGNOSTIC] rootAnimations=\(animationCount)")
        dumpEntity(entity, depth: 0)
        print("[ChatAI-RIG-DIAGNOSTIC] end")
    }

    private static func dumpEntity(_ entity: Entity, depth: Int) {
        let indent = String(repeating: "  ", count: min(depth, 20))
        let componentSummary = String(describing: entity.components).replacingOccurrences(of: "\n", with: " ")
        print("[ChatAI-RIG-DIAGNOSTIC] \(indent)entity=\(entity.name.isEmpty ? "<unnamed>" : entity.name) type=\(String(describing: type(of: entity))) animations=\(entity.availableAnimations.count) components=\(componentSummary)")
        for child in entity.children { dumpEntity(child, depth: depth + 1) }
    }

    private static func findMouthControl(in entity: Entity) -> Entity? {
        let normalizedName = entity.name.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        let candidates = ["jaw", "lowerjaw", "mandible", "mouth", "lowerlip", "liplower", "mixamorigrigjaw", "mixamorigjaw"]
        if candidates.contains(where: { normalizedName == $0 || normalizedName.contains($0) }) { return entity }
        for child in entity.children {
            if let match = findMouthControl(in: child) { return match }
        }
        return nil
    }

    private func makeLight(color: UIColor, intensity: Float, position: SIMD3<Float>) -> Entity {
        let light = Entity()
        var component = PointLightComponent()
        component.color = color
        component.intensity = intensity
        light.components.set(component)
        light.position = position
        return light
    }
}

private struct FallbackCompanionRobot: View {
    let speaking: Bool
    @State private var blink = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 330, geo.size.height / 390)
            VStack(spacing: 0) {
                HStack(spacing: 62 * s) {
                    antenna(scale: s)
                    antenna(scale: s)
                }
                .padding(.bottom, -4 * s)
                ZStack {
                    RoundedRectangle(cornerRadius: 82 * s)
                        .fill(LinearGradient(colors: [.white, Color(red: 0.72, green: 0.86, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 82 * s).stroke(Color.pink.opacity(0.85), lineWidth: 5 * s))
                        .frame(width: 270 * s, height: 245 * s)
                        .shadow(color: .cyan.opacity(0.25), radius: 22 * s)
                    RoundedRectangle(cornerRadius: 58 * s)
                        .fill(Color(red: 0.015, green: 0.025, blue: 0.05))
                        .overlay(RoundedRectangle(cornerRadius: 58 * s).stroke(Color.cyan.opacity(0.85), lineWidth: 3 * s))
                        .frame(width: 228 * s, height: 164 * s)
                        .overlay {
                            VStack(spacing: 22 * s) {
                                HStack(spacing: 40 * s) { eye(scale: s); eye(scale: s) }
                                Capsule().fill(Color.pink).frame(width: (speaking ? 38 : 28) * s, height: (speaking ? 17 : 5) * s).shadow(color: .pink.opacity(0.8), radius: 7 * s)
                            }
                        }
                    HStack(spacing: 0) { ear(scale: s); Spacer(); ear(scale: s) }.frame(width: 300 * s)
                }
                RoundedRectangle(cornerRadius: 12 * s)
                    .fill(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.34), Color(white: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 12 * s).stroke(Color.cyan, lineWidth: 2 * s))
                    .frame(width: 92 * s, height: 48 * s)
                    .overlay(Capsule().fill(Color.cyan).frame(width: 48 * s, height: 4 * s))
                Text("ChatAI").font(.system(size: 15 * s, weight: .bold, design: .rounded)).foregroundStyle(.cyan.opacity(0.9)).padding(.top, 9 * s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private func antenna(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle().fill(Color.pink).frame(width: 20 * scale, height: 20 * scale).shadow(color: .pink.opacity(0.8), radius: 8 * scale)
            Capsule().fill(Color.cyan).frame(width: 5 * scale, height: 35 * scale)
        }
    }
    private func eye(scale: CGFloat) -> some View {
        Ellipse().fill(RadialGradient(colors: [.white, .cyan, Color.blue.opacity(0.8)], center: .topLeading, startRadius: 2, endRadius: 34 * scale)).frame(width: 42 * scale, height: 56 * scale)
            .overlay(Ellipse().fill(Color.black).frame(width: 17 * scale, height: 31 * scale))
            .overlay(Circle().fill(.white).frame(width: 9 * scale, height: 9 * scale).offset(x: -8 * scale, y: -13 * scale))
            .shadow(color: .cyan.opacity(0.85), radius: 8 * scale)
    }
    private func ear(scale: CGFloat) -> some View {
        Circle().fill(Color.white).frame(width: 36 * scale, height: 36 * scale).overlay(Circle().stroke(Color.pink, lineWidth: 4 * scale)).overlay(Circle().fill(Color.cyan).frame(width: 14 * scale, height: 14 * scale))
    }
}
