import SwiftUI
import UIKit
import SceneKit

/// ChatAI companion screen with a simple floating anime face and Gemini Live voice interaction.
struct CompanionChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveManager = LiveVoiceManager()
    @AppStorage("live_model") private var liveModel = "gemini-3.8-live"
    @AppStorage("live_voice") private var liveVoice = "Zephyr"
    @AppStorage("live_persona") private var livePersona = LivePersona.defaultText
    @AppStorage("live_barge_in") private var liveBargeIn = false
    @State private var emotion: CompanionEmotion = .idle
    @State private var showConversation = true
    @State private var isVoiceChatActive = false
    @State private var touchMessage: String?
    @State private var isNight = Calendar.current.component(.hour, from: Date()) >= 19 || Calendar.current.component(.hour, from: Date()) < 6

    var body: some View {
        ZStack {
            LinearGradient(colors: isNight ? [Color(red: 0.035, green: 0.055, blue: 0.16), Color(red: 0.18, green: 0.12, blue: 0.31)] : [Color(red: 0.18, green: 0.27, blue: 0.43), Color(red: 0.57, green: 0.35, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ZStack(alignment: .bottom) {
                    GeometryReader { geo in
                        Companion3DStage(emotion: emotionName, isNight: isNight, isSpeaking: liveManager.aiSpeaking)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .contentShape(Rectangle())
                            .gesture(SpatialTapGesture().onEnded { value in
                                let xRatio = value.location.x / max(geo.size.width, 1)
                                reactToTouch(xRatio < 0.38 || xRatio > 0.62 ? .cheek : .head)
                            })
                    }
                    VStack(spacing: 12) {
                        HStack {
                            Label(statusText, systemImage: statusSymbol).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                            Button { isNight.toggle() } label: {
                                Image(systemName: isNight ? "moon.stars.fill" : "sun.max.fill").font(.title3).foregroundStyle(.white).frame(width: 42, height: 42).background(.ultraThinMaterial, in: Circle())
                            }.accessibilityLabel("Đổi môi trường ngày đêm")
                        }
                        if let touchMessage {
                            Text(touchMessage).font(.subheadline.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if showConversation { conversationPreview }
                    }.padding(16)
                }
                controls
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: liveManager.lines.count) { _ in
            if let line = liveManager.lines.last { touchMessage = line.text; emotion = line.role == .assistant ? .happy : .thinking }
        }
        .onChange(of: liveManager.errorText) { message in if let message, !message.isEmpty { touchMessage = message } }
        .onChange(of: liveManager.aiSpeaking) { speaking in if speaking { emotion = .happy } }
        .onDisappear { liveManager.end() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: { Image(systemName: "chevron.down").font(.headline).frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle()) }
            VStack(alignment: .leading, spacing: 2) { Text("ChatAI Companion").font(.headline); Text(viewModel.selectedProvider.rawValue).font(.caption).foregroundStyle(.white.opacity(0.68)) }
            Spacer()
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { showConversation.toggle() } } label: { Image(systemName: showConversation ? "text.bubble" : "text.bubble.fill").font(.title3).frame(width: 42, height: 42).background(.ultraThinMaterial, in: Circle()) }.accessibilityLabel("Ẩn hoặc hiện hội thoại")
        }.foregroundStyle(.white).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
    }

    private var conversationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lastUser = viewModel.messages.last(where: { $0.role == .user }) { Text("ANH").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.55)); Text(lastUser.content).font(.subheadline).lineLimit(2) }
            if let lastReply = viewModel.messages.last(where: { $0.role == .assistant }) { Text("CHATAI").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.cyan.opacity(0.9)); Text(lastReply.content).font(.subheadline).lineLimit(3) }
            else if viewModel.isSending { Label("Đang suy nghĩ...", systemImage: "sparkles").font(.subheadline) }
            else if viewModel.messages.isEmpty { Text("Chào anh! Mình trò chuyện nhé.").font(.subheadline) }
        }.foregroundStyle(.white).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                if liveManager.state == .idle { startGeminiLive() } else { liveManager.end(); isVoiceChatActive = false }
            } label: { Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill").font(.title3).frame(width: 50, height: 50).background(liveManager.state == .idle ? .white.opacity(0.12) : .red.opacity(0.8), in: Circle()) }
            .accessibilityLabel(liveManager.state == .idle ? "Bắt đầu Gemini Live" : "Kết thúc Gemini Live")
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showConversation = true; isVoiceChatActive = true }
                if liveManager.state == .idle { startGeminiLive() }
            } label: {
                Label(liveManager.state == .live ? (liveManager.aiSpeaking ? "AI đang nói..." : "Đang nghe anh") : (liveManager.state == .connecting ? "Đang kết nối Gemini..." : "Tiếp tục chat"), systemImage: "waveform").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).frame(height: 50).background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).frame(width: 50, height: 50).background(.red.opacity(0.8), in: Circle()) }.accessibilityLabel("Đóng màn hình companion")
        }.foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 12).background(.black.opacity(0.22))
    }

    private func startGeminiLive() { isVoiceChatActive = true; showConversation = true; liveManager.start(model: liveModel, voice: liveVoice, persona: livePersona, bargeIn: liveBargeIn) }
    private enum TouchTarget { case head, cheek }
    private func reactToTouch(_ target: TouchTarget) {
        let prompt: String
        switch target {
        case .head: prompt = "Anh vừa chạm nhẹ vào đầu em. Hãy phản ứng ấm áp, tự nhiên bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."; emotion = .happy
        case .cheek: prompt = "Anh vừa chạm nhẹ vào má em. Hãy phản ứng hơi ngại ngùng, dễ thương bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."; emotion = .shy
        }
        if liveManager.state == .live { liveManager.sendText(prompt); touchMessage = nil } else { touchMessage = "Bấm 'Tiếp tục chat' để kết nối Gemini Live trước nhé." }
    }
    private var emotionName: String { switch emotion { case .idle: "idle"; case .happy: "happy"; case .thinking: "thinking"; case .shy: "shy"; case .surprised: "surprised" } }
    private var statusText: String { switch emotion { case .idle: "Đang ở đây với anh"; case .happy: "Em đang vui"; case .thinking: "Đang suy nghĩ"; case .shy: "Em hơi ngại..."; case .surprised: "Ơ, bất ngờ quá!" } }
    private var statusSymbol: String { switch emotion { case .idle: "sparkles"; case .happy: "face.smiling"; case .thinking: "ellipsis.bubble"; case .shy: "heart.fill"; case .surprised: "exclamationmark.bubble" } }
}

private enum CompanionEmotion { case idle, happy, thinking, shy, surprised }

/// Face-only SceneKit companion: no torso, arms, legs, clothing or full-body geometry.
private struct Companion3DStage: UIViewRepresentable {
    let emotion: String
    let isNight: Bool
    let isSpeaking: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(); view.scene = makeScene(); view.backgroundColor = .clear; view.isPlaying = true; view.antialiasingMode = .multisampling4X; view.allowsCameraControl = false; view.autoenablesDefaultLighting = false; view.rendersContinuously = true; return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let scene = view.scene, let root = scene.rootNode.childNode(withName: "companionRoot", recursively: true) else { return }
        let face = root.childNode(withName: "face", recursively: true); face?.eulerAngles.z = emotion == "shy" ? 0.10 : (emotion == "thinking" ? -0.08 : 0); face?.eulerAngles.y = emotion == "thinking" ? -0.10 : 0
        let mouth = root.childNode(withName: "mouth", recursively: true); mouth?.scale.y = isSpeaking ? 2.9 : (emotion == "surprised" ? 2.2 : 1.0); mouth?.scale.x = emotion == "happy" ? 1.45 : 1.0
        let eyeOffset: Float = emotion == "thinking" ? -0.025 : 0; root.childNode(withName: "irisL", recursively: true)?.position.x = -0.52 + eyeOffset; root.childNode(withName: "irisR", recursively: true)?.position.x = 0.52 + eyeOffset; root.childNode(withName: "pupilL", recursively: true)?.position.x = -0.52 + eyeOffset; root.childNode(withName: "pupilR", recursively: true)?.position.x = 0.52 + eyeOffset
        scene.rootNode.childNode(withName: "environmentGlow", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = isNight ? UIColor(red: 0.30, green: 0.38, blue: 0.95, alpha: 0.22) : UIColor(red: 0.95, green: 0.65, blue: 0.40, alpha: 0.20)
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = UIColor(white: 0.82, alpha: 1)

        let camera = SCNCamera()
        camera.fieldOfView = 30
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 8.4)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        addLight(to: scene, type: .omni, intensity: 1050,
                 color: UIColor(red: 1, green: 0.91, blue: 0.96, alpha: 1),
                 position: SCNVector3(-3, 4, 5))
        addLight(to: scene, type: .omni, intensity: 850,
                 color: UIColor(red: 0.25, green: 0.88, blue: 1, alpha: 1),
                 position: SCNVector3(3, 1, 4))
        addLight(to: scene, type: .omni, intensity: 550,
                 color: UIColor(red: 1, green: 0.38, blue: 0.68, alpha: 1),
                 position: SCNVector3(0, -3, 2))

        let root = SCNNode()
        root.name = "companionRoot"
        scene.rootNode.addChildNode(root)

        let pearl = mat(UIColor(red: 0.94, green: 0.97, blue: 1, alpha: 1), rough: 0.22, metal: 0.12)
        let pink = mat(UIColor(red: 1, green: 0.43, blue: 0.72, alpha: 1), rough: 0.25, metal: 0.12)
        let palePink = mat(UIColor(red: 1, green: 0.72, blue: 0.84, alpha: 1), rough: 0.3)
        let blue = mat(UIColor(red: 0.28, green: 0.82, blue: 1, alpha: 1), rough: 0.18, metal: 0.08)
        let visorMat = mat(UIColor(red: 0.012, green: 0.035, blue: 0.075, alpha: 1), rough: 0.12, metal: 0.32)
        let cyan = mat(UIColor(red: 0.12, green: 0.96, blue: 1, alpha: 1), rough: 0.16)
        cyan.emission.contents = UIColor(red: 0.04, green: 0.88, blue: 1, alpha: 1)
        let deepCyan = mat(UIColor(red: 0.02, green: 0.48, blue: 0.66, alpha: 1), rough: 0.2)
        let white = mat(.white, rough: 0.12)
        let mouthMat = mat(UIColor(red: 1, green: 0.38, blue: 0.69, alpha: 1), rough: 0.24)
        mouthMat.emission.contents = UIColor(red: 1, green: 0.16, blue: 0.5, alpha: 1)

        // Soft halo behind the head.
        let halo = sphere(root, "environmentGlow", radius: 1.95,
                          position: SCNVector3(0, 0, -0.95),
                          material: mat(UIColor(red: 0.16, green: 0.73, blue: 1, alpha: 0.20), rough: 1),
                          scale: SCNVector3(1.12, 1.05, 0.12), segments: 64)
        halo.geometry?.firstMaterial?.lightingModel = .constant

        // Two round ears with blue inner discs and pink outer trim.
        for (x, suffix) in [(-1.42, "L"), (1.42, "R")] as [(Float, String)] {
            let ear = sphere(root, "ear" + suffix, radius: 0.39,
                             position: SCNVector3(x, 0.02, -0.02), material: pink,
                             scale: SCNVector3(1, 1, 0.45), segments: 40)
            ear.geometry?.firstMaterial = pink
            sphere(root, "earInner" + suffix, radius: 0.27,
                   position: SCNVector3(x, 0.02, 0.16), material: blue,
                   scale: SCNVector3(1, 1, 0.42), segments: 40)
            sphere(root, "earCore" + suffix, radius: 0.12,
                   position: SCNVector3(x, 0.02, 0.28), material: palePink,
                   scale: SCNVector3(1, 1, 0.35), segments: 24)
        }

        // Pearl-white rounded robot shell, outlined with a pastel-pink rim.
        let rimGeo = SCNSphere(radius: 1.58)
        rimGeo.segmentCount = 64
        rimGeo.firstMaterial = pink
        let rim = SCNNode(geometry: rimGeo)
        rim.name = "headRim"
        rim.scale = SCNVector3(1.12, 1.08, 0.68)
        rim.position = SCNVector3(0, 0, 0.02)
        root.addChildNode(rim)

        let shellGeo = SCNSphere(radius: 1.53)
        shellGeo.segmentCount = 64
        shellGeo.firstMaterial = pearl
        let shell = SCNNode(geometry: shellGeo)
        shell.name = "face"
        shell.scale = SCNVector3(1.12, 1.08, 0.70)
        shell.position = SCNVector3(0, 0.035, 0.10)
        root.addChildNode(shell)

        // Rounded cap crown and pastel seam.
        let capGeo = SCNSphere(radius: 1.40)
        capGeo.segmentCount = 64
        capGeo.firstMaterial = pearl
        let cap = SCNNode(geometry: capGeo)
        cap.name = "robotCap"
        cap.scale = SCNVector3(1.10, 0.55, 0.67)
        cap.position = SCNVector3(0, 0.83, 0.08)
        root.addChildNode(cap)

        let seamGeo = SCNTorus(ringRadius: 1.16, pipeRadius: 0.045)
        seamGeo.firstMaterial = pink
        let seam = SCNNode(geometry: seamGeo)
        seam.name = "capSeam"
        seam.position = SCNVector3(0, 0.53, 0.88)
        seam.scale = SCNVector3(1.04, 0.56, 0.6)
        root.addChildNode(seam)

        // Two short antennae with glowing pink tips.
        for (x, suffix) in [(-0.48, "L"), (0.48, "R")] as [(Float, String)] {
            let stemGeo = SCNCylinder(radius: 0.045, height: 0.42)
            stemGeo.firstMaterial = blue
            let stem = SCNNode(geometry: stemGeo)
            stem.name = "antennaStem" + suffix
            stem.position = SCNVector3(x, 1.68, 0.02)
            stem.eulerAngles.z = x < 0 ? -0.16 : 0.16
            root.addChildNode(stem)
            let tip = sphere(root, "antennaTip" + suffix, radius: 0.14,
                             position: SCNVector3(x * 1.08, 1.91, 0.04),
                             material: pink, segments: 32)
            tip.geometry?.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.24, blue: 0.65, alpha: 1)
            sphere(root, "antennaHighlight" + suffix, radius: 0.045,
                   position: SCNVector3(x * 1.08 - 0.035, 1.96, 0.14), material: white, segments: 16)
        }

        // Glossy black glass visor across the front.
        let visorGeo = SCNSphere(radius: 1)
        visorGeo.segmentCount = 64
        visorGeo.firstMaterial = visorMat
        let visor = SCNNode(geometry: visorGeo)
        visor.name = "visor"
        visor.position = SCNVector3(0, 0.05, 1.05)
        visor.scale = SCNVector3(1.24, 0.68, 0.18)
        root.addChildNode(visor)

        // Cyan luminous eyes, deep pupils and white specular highlights.
        for (x, suffix) in [(-0.53, "L"), (0.53, "R")] as [(Float, String)] {
            sphere(root, "eyeGlow" + suffix, radius: 0.34,
                   position: SCNVector3(x, 0.12, 1.24), material: deepCyan,
                   scale: SCNVector3(0.78, 1.18, 0.20), segments: 40)
            let eye = sphere(root, "eyeWhite" + suffix, radius: 0.29,
                             position: SCNVector3(x, 0.12, 1.29), material: cyan,
                             scale: SCNVector3(0.82, 1.18, 0.22), segments: 40)
            eye.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.05, green: 0.92, blue: 1, alpha: 1)
            sphere(root, "iris" + suffix, radius: 0.13,
                   position: SCNVector3(x, 0.10, 1.34), material: deepCyan,
                   scale: SCNVector3(0.9, 1.05, 0.3), segments: 32)
            sphere(root, "pupil" + suffix, radius: 0.075,
                   position: SCNVector3(x, 0.10, 1.37), material: visorMat,
                   scale: SCNVector3(0.9, 1.08, 0.25), segments: 24)
            sphere(root, "sparkle" + suffix, radius: 0.065,
                   position: SCNVector3(x - 0.055, 0.22, 1.40), material: white, segments: 16)
            sphere(root, "sparkleSmall" + suffix, radius: 0.027,
                   position: SCNVector3(x + 0.06, 0.04, 1.405), material: white, segments: 12)
        }

        // Small pink cheeks and an expressive mouth.
        for x in [-0.86, 0.86] as [Float] {
            let cheek = sphere(root, x < 0 ? "blushL" : "blushR", radius: 0.13,
                               position: SCNVector3(x, -0.40, 1.15), material: palePink,
                               scale: SCNVector3(1.4, 0.55, 0.22), segments: 24)
            cheek.geometry?.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.35, blue: 0.65, alpha: 1)
        }
        sphere(root, "mouth", radius: 0.10,
               position: SCNVector3(0, -0.48, 1.22), material: mouthMat,
               scale: SCNVector3(1.15, 0.38, 0.20), segments: 32)

        root.runAction(.repeatForever(.sequence([
            .scale(to: 1.008, duration: 1.6),
            .scale(to: 1.000, duration: 1.6)
        ])), forKey: "breathing")
        faceIdleAction(root: root)
        return scene
    }

    private func faceIdleAction(root: SCNNode) {
        guard let face = root.childNode(withName: "face", recursively: true) else { return }
        face.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: 0.012, duration: 1.8),
            .rotateTo(x: 0, y: 0, z: -0.012, duration: 1.8)
        ])), forKey: "faceIdle")
    }

    @discardableResult
    private func sphere(_ parent: SCNNode, _ name: String, radius: CGFloat, position: SCNVector3, material: SCNMaterial, scale: SCNVector3? = nil, segments: Int = 48) -> SCNNode {
        let geometry = SCNSphere(radius: radius); geometry.segmentCount = segments; geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry); node.name = name; node.position = position; if let scale { node.scale = scale }; parent.addChildNode(node); return node
    }

    private func mat(_ color: UIColor, rough: CGFloat = 0.48, metal: CGFloat = 0) -> SCNMaterial {
        let material = SCNMaterial(); material.diffuse.contents = color; material.roughness.contents = rough; material.metalness.contents = metal; material.lightingModel = .physicallyBased; return material
    }

    private func addLight(to scene: SCNScene, type: SCNLight.LightType, intensity: CGFloat, color: UIColor, position: SCNVector3) {
        let light = SCNLight(); light.type = type; light.intensity = intensity; light.color = color
        let node = SCNNode(); node.light = light; node.position = position; scene.rootNode.addChildNode(node)
    }
}
