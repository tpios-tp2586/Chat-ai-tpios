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
        let scene = SCNScene(); scene.background.contents = UIColor.clear; scene.lightingEnvironment.contents = UIColor(white: 0.78, alpha: 1)
        let camera = SCNCamera(); camera.fieldOfView = 24; camera.zNear = 0.1; camera.zFar = 60
        let cameraNode = SCNNode(); cameraNode.camera = camera; cameraNode.position = SCNVector3(0, 0, 7.0); cameraNode.look(at: SCNVector3(0, 0, 0)); scene.rootNode.addChildNode(cameraNode)
        addLight(to: scene, type: .omni, intensity: 950, color: UIColor(red: 1.0, green: 0.95, blue: 0.90, alpha: 1), position: SCNVector3(-3.5, 4.0, 5.0))
        addLight(to: scene, type: .omni, intensity: 450, color: UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1), position: SCNVector3(3.5, 1.5, 3.0))

        let root = SCNNode(); root.name = "companionRoot"; scene.rootNode.addChildNode(root)
        let skin = mat(UIColor(red: 0.98, green: 0.82, blue: 0.74, alpha: 1), rough: 0.58)
        let dark = mat(UIColor(red: 0.045, green: 0.025, blue: 0.065, alpha: 1), rough: 0.55)
        let iris = mat(UIColor(red: 0.22, green: 0.50, blue: 0.82, alpha: 1), rough: 0.18)
        let white = mat(.white, rough: 0.50)
        let mouthMat = mat(UIColor(red: 0.18, green: 0.025, blue: 0.055, alpha: 1), rough: 0.62)
        let blush = mat(UIColor(red: 1.0, green: 0.42, blue: 0.58, alpha: 0.65), rough: 0.70)

        let faceGeo = SCNSphere(radius: 1.55); faceGeo.segmentCount = 64; faceGeo.firstMaterial = skin
        let face = SCNNode(geometry: faceGeo); face.name = "face"; face.scale = SCNVector3(1.00, 1.08, 0.68); root.addChildNode(face)
        let hairGeo = SCNSphere(radius: 1.60); hairGeo.segmentCount = 64; hairGeo.firstMaterial = dark
        let hair = SCNNode(geometry: hairGeo); hair.name = "hairCap"; hair.position = SCNVector3(0, 0.28, -0.10); hair.scale = SCNVector3(1.02, 0.72, 0.70); hair.renderingOrder = -1; root.addChildNode(hair)

        for (x, suffix) in [(-0.52, "L"), (0.52, "R")] as [(Float, String)] {
            let eye = sphere(root, "eyeWhite" + suffix, radius: 0.34, position: SCNVector3(x, 0.20, 1.00), material: white, scale: SCNVector3(0.78, 1.28, 0.24), segments: 48)
            let irisNode = sphere(root, "iris" + suffix, radius: 0.235, position: SCNVector3(x, 0.18, 1.10), material: iris, scale: SCNVector3(0.82, 1.18, 0.24), segments: 48)
            sphere(root, "pupil" + suffix, radius: 0.115, position: SCNVector3(x, 0.18, 1.16), material: dark, scale: SCNVector3(0.82, 1.24, 0.24), segments: 32)
            sphere(root, "sparkle" + suffix, radius: 0.055, position: SCNVector3(x - 0.055, 0.29, 1.19), material: white, segments: 16)
            let lashGeo = SCNBox(width: 0.55, height: 0.055, length: 0.035, chamferRadius: 0.02); lashGeo.firstMaterial = dark
            let lash = SCNNode(geometry: lashGeo); lash.name = "lash" + suffix; lash.position = SCNVector3(x, 0.56, 1.05); lash.eulerAngles.z = suffix == "L" ? -0.06 : 0.06; root.addChildNode(lash)
            let blink = SCNAction.sequence([.wait(duration: suffix == "L" ? 3.0 : 3.15), .customAction(duration: 0.06) { node, _ in node.scale.y = 0.06 }, .customAction(duration: 0.10) { node, _ in node.scale.y = node.name?.hasPrefix("eyeWhite") == true ? 1.28 : 1.18 }])
            eye.runAction(.repeatForever(blink), forKey: "blink"); irisNode.runAction(.repeatForever(blink), forKey: "blink")
        }

        sphere(root, "blushL", radius: 0.16, position: SCNVector3(-0.72, -0.35, 1.00), material: blush, scale: SCNVector3(1.45, 0.45, 0.18), segments: 24)
        sphere(root, "blushR", radius: 0.16, position: SCNVector3(0.72, -0.35, 1.00), material: blush, scale: SCNVector3(1.45, 0.45, 0.18), segments: 24)
        sphere(root, "mouth", radius: 0.11, position: SCNVector3(0, -0.72, 1.05), material: mouthMat, scale: SCNVector3(1.45, 0.48, 0.20), segments: 32)

        let glowGeo = SCNSphere(radius: 2.0); glowGeo.firstMaterial = mat(UIColor(red: 0.50, green: 0.58, blue: 1.0, alpha: 0.10), rough: 1); glowGeo.firstMaterial?.isDoubleSided = true
        let glow = SCNNode(geometry: glowGeo); glow.name = "environmentGlow"; glow.position = SCNVector3(0, 0, -1.5); glow.scale = SCNVector3(1.10, 1.10, 0.08); root.addChildNode(glow)
        root.runAction(.repeatForever(.sequence([.scale(to: 1.012, duration: 1.8), .scale(to: 1.000, duration: 1.8)])), forKey: "breathing")
        face.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: 0.018, duration: 1.7), .rotateTo(x: 0, y: 0, z: -0.018, duration: 1.7)])), forKey: "faceIdle")
        return scene
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
