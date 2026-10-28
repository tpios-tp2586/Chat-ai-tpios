import SwiftUI
import SceneKit
import UIKit

/// Displays the real 3D companion model. Chat and voice logic are intentionally untouched.
struct ChatAIHead3DView: View {
    var headRotation: Float = 0
    var speaking: Bool = false

    @State private var loadMessage = "Đang tải mô hình 3D…"
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [activeTheme.background, activeTheme.surface], startPoint: .top, endPoint: .bottom)

            CompanionSceneView(headRotation: headRotation, speaking: speaking) { message in
                loadMessage = message
            }

            VStack {
                Spacer()
                if !loadMessage.isEmpty {
                    Text(loadMessage)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .tint(activeTheme.accent)
    }
}

private struct CompanionSceneView: UIViewRepresentable {
    let headRotation: Float
    let speaking: Bool
    let onStatus: (String) -> Void
    private let modelResourceName = "Model-02"

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(ChatAIThemeStore.current.background)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X

        guard let url = Bundle.main.url(forResource: modelResourceName, withExtension: "usdz")
            ?? Bundle.main.url(forResource: modelResourceName, withExtension: "usdz", subdirectory: "Companion") else {
            setStatus("[ChatAI-RIG] ERROR: Model-02.usdz không có trong Bundle")
            return view
        }

        do {
            let scene = try SCNScene(url: url, options: nil)

            let camera = SCNCamera()
            camera.fieldOfView = 42
            let cameraNode = SCNNode()
            cameraNode.name = "ChatAICamera"
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 1.8)
            scene.rootNode.addChildNode(cameraNode)

            var geometryCount = 0
            var morpherNode: SCNNode?
            var morphCount = 0

            func inspect(_ node: SCNNode) {
                if node.geometry != nil { geometryCount += 1 }
                if let morpher = node.morpher, !morpher.targets.isEmpty {
                    morpherNode = node
                    morphCount = morpher.targets.count
                    morpher.calculationMode = .normalized
                }
                node.childNodes.forEach(inspect)
            }
            inspect(scene.rootNode)

            guard geometryCount > 0 else {
                setStatus("[ChatAI-RIG] ERROR: USDZ load được nhưng không có geometry")
                return view
            }

            let modelRoot = SCNNode()
            modelRoot.name = "ChatAICompanionModel"

            // Keep the camera outside the model hierarchy.
            scene.rootNode.childNodes
                .filter { $0 !== cameraNode }
                .forEach {
                    $0.removeFromParentNode()
                    modelRoot.addChildNode($0)
                }

            // Preserve the imported orientation, then fit the complete model to the camera.
            let (minV, maxV) = modelRoot.boundingBox
            let width = maxV.x - minV.x
            let height = maxV.y - minV.y
            let depth = maxV.z - minV.z
            let largest = max(width, max(height, depth))

            if largest.isFinite && largest > 0 {
                let scale = 1.45 / largest
                modelRoot.scale = SCNVector3(scale, scale, scale)
                modelRoot.position = SCNVector3(
                    -(minV.x + maxV.x) * 0.5 * scale,
                    -(minV.y + maxV.y) * 0.5 * scale,
                    -(minV.z + maxV.z) * 0.5 * scale
                )
            }

            scene.rootNode.addChildNode(modelRoot)
            view.scene = scene
            view.pointOfView = cameraNode
            view.isPlaying = true
            view.delegate = context.coordinator

            context.coordinator.modelRoot = modelRoot
            context.coordinator.morpherNode = morpherNode
            context.coordinator.morphCount = morphCount
            context.coordinator.speaking = speaking
            context.coordinator.currentHeadRotation = headRotation

            setStatus("[ChatAI-RIG] renderer=SceneKit\ngeometryNodes=\(geometryCount)\nmorphTargets=\(morphCount)\nmodel=Model-02.usdz\nSpeaking drives morph 19; chatbot/voice unchanged.")
        } catch {
            setStatus("[ChatAI-RIG] ERROR: Không tải được Model-02.usdz\n\(error.localizedDescription)")
        }

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.speaking = speaking
        context.coordinator.currentHeadRotation = headRotation
    }

    private func setStatus(_ message: String) {
        DispatchQueue.main.async {
            onStatus(message)
        }
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var modelRoot: SCNNode?
        weak var morpherNode: SCNNode?
        var morphCount = 0
        var speaking = false
        var currentHeadRotation: Float = 0
        private var elapsed: Float = 0
        private var lastTime: TimeInterval?

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let delta = Float(min(1.0 / 20.0, max(0, time - (lastTime ?? time))))
            lastTime = time
            elapsed += delta

            guard let root = modelRoot else { return }
            root.eulerAngles.y = currentHeadRotation

            guard let morpher = morpherNode?.morpher, morphCount > 19 else { return }
            let targetWeight: CGFloat
            if speaking {
                targetWeight = CGFloat(max(0, sin(elapsed * 11) * 0.5 + sin(elapsed * 18.7) * 0.25)) * 0.85
            } else {
                targetWeight = 0
            }
            morpher.setWeight(targetWeight, forTargetAt: 19)
        }
    }
}
