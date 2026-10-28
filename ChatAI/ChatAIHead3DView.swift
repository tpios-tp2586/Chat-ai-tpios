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
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [activeTheme.background, activeTheme.surface], startPoint: .top, endPoint: .bottom)

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
                            .tint(activeTheme.accent)

                            Button {
                                loadMessage = "Đã xoá log"
                                copyStatus = ""
                            } label: {
                                Label("Xoá", systemImage: "trash")
                                    .font(.caption2.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(activeTheme.accent)

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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .tint(activeTheme.accent)
        .onAppear { modelLoaded = false }
    }
}

private struct CompanionRealityView: UIViewRepresentable {
    let headRotation: Float
    let speaking: Bool
    let onResult: (Bool, String) -> Void
    private let modelResourceName = "Model-02"

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(ChatAIThemeStore.current.background)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X

        guard let url = Bundle.main.url(forResource: modelResourceName, withExtension: "usdz")
            ?? Bundle.main.url(forResource: modelResourceName, withExtension: "usdz", subdirectory: "Companion") else {
            DispatchQueue.main.async { onResult(false, "Không tìm thấy Model-02.usdz trong app bundle.") }
            return view
        }

        do {
            let scene = try SCNScene(url: url, options: nil)
            let camera = SCNCamera()
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.02, 1.75)
            scene.rootNode.addChildNode(cameraNode)
            scene.background.contents = UIColor(ChatAIThemeStore.current.background)

            var geometryCount = 0
            var morpherNode: SCNNode?
            var morphCount = 0
            func inspect(_ node: SCNNode) {
                if node.geometry != nil { geometryCount += 1 }
                if let morpher = node.morpher, !morpher.targets.isEmpty {
                    morpherNode = node
                    morphCount = morpher.targets.count
                    morpher.calculationMode = .normalized
                    morpher.targets.forEach { $0.name = $0.name ?? "" }
                }
                node.childNodes.forEach(inspect)
            }
            inspect(scene.rootNode)

            // Model-02 has 42 numeric morph slots. Geometry inspection found slot 19
            // affects the lower central face; slots 0 and 1 affect opposite side regions.
            // Keep the existing model transform and drive only the lower-face morph while speaking.
            let modelRoot = SCNNode()
            modelRoot.name = "ChatAICompanionGLB"
            modelRoot.eulerAngles.x = -.pi / 2
            let contentRoot = scene.rootNode
            let children = contentRoot.childNodes.filter { $0 !== cameraNode }
            children.forEach { $0.removeFromParentNode(); modelRoot.addChildNode($0) }
            scene.rootNode.addChildNode(modelRoot)

            let (minV, maxV) = modelRoot.boundingBox
            let largest = max(maxV.x - minV.x, max(maxV.y - minV.y, maxV.z - minV.z))
            if largest.isFinite && largest > 0 {
                modelRoot.scale = SCNVector3(1.55 / largest, 1.55 / largest, 1.55 / largest)
                modelRoot.position = SCNVector3(-(minV.x + maxV.x) * 0.5, -(minV.y + maxV.y) * 0.5, -(minV.z + maxV.z) * 0.5)
            }
            context.coordinator.modelRoot = modelRoot
            context.coordinator.morpherNode = morpherNode
            context.coordinator.morphCount = morphCount
            context.coordinator.speaking = speaking
            context.coordinator.currentHeadRotation = headRotation
            view.scene = scene
            view.pointOfView = cameraNode
            view.isPlaying = true
            view.delegate = context.coordinator
            DispatchQueue.main.async {
                onResult(true, "[ChatAI-RIG] renderer=SceneKit\ngeometryNodes=\(geometryCount)\nmorphTargets=\(morphCount)\nmouthMorph=19 (lower-face candidate)\nSpeaking drives morph weight; chatbot/voice pipeline unchanged.")
            }
        } catch {
            DispatchQueue.main.async { onResult(false, "Không tải được USDZ: \(error.localizedDescription)") }
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.speaking = speaking
        context.coordinator.currentHeadRotation = headRotation
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var modelRoot: SCNNode?
        weak var morpherNode: SCNNode?
        var morphCount = 0
        var speaking = false
        var currentHeadRotation: Float = 0
        var elapsed: Float = 0

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let delta = Float(min(1.0 / 20.0, max(0, time - (lastTime ?? time))))
            lastTime = time
            elapsed += delta
            DispatchQueue.main.async {
                guard let root = self.modelRoot else { return }
                root.eulerAngles = SCNVector3(-Float.pi / 2, self.currentHeadRotation, 0)
                guard let morpher = self.morpherNode?.morpher, self.morphCount > 19 else { return }
                let pulse: CGFloat = self.speaking
                    ? CGFloat(max(0, sin(self.elapsed * 11) * 0.5 + sin(self.elapsed * 18.7) * 0.25))
                    : 0
                morpher.setWeight(pulse * 0.85, forTargetAt: 19)
            }
        }

        private var lastTime: TimeInterval?
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
