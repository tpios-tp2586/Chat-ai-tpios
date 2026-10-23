import SwiftUI
import UIKit
import SceneKit

/// 2D anime companion screen. Keeps Gemini Live interactions while the dedicated sprite asset is prepared.
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
    @State private var isNight = Calendar.current.component(.hour, from: Date()) >= 19 ||
        Calendar.current.component(.hour, from: Date()) < 6

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isNight
                    ? [Color(red: 0.035, green: 0.055, blue: 0.16), Color(red: 0.18, green: 0.12, blue: 0.31)]
                    : [Color(red: 0.18, green: 0.27, blue: 0.43), Color(red: 0.57, green: 0.35, blue: 0.31)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ZStack(alignment: .bottom) {
                    GeometryReader { geo in
                        Companion3DStage(emotion: emotionName, isNight: isNight, isSpeaking: liveManager.aiSpeaking)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture().onEnded { value in
                                    let point = value.location
                                    let ratio = point.y / max(geo.size.height, 1)
                                    if ratio < 0.48 {
                                        let xRatio = point.x / max(geo.size.width, 1)
                                        reactToTouch(xRatio < 0.38 || xRatio > 0.62 ? .cheek : .head)
                                    } else {
                                        reactToTouch(.body)
                                    }
                                }
                            )
                    }

                    VStack(spacing: 12) {
                        HStack {
                            Label(statusText, systemImage: statusSymbol)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                            Button {
                                isNight.toggle()
                            } label: {
                                Image(systemName: isNight ? "moon.stars.fill" : "sun.max.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .accessibilityLabel("Đổi môi trường ngày đêm")
                        }

                        if let touchMessage {
                            Text(touchMessage)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if showConversation {
                            conversationPreview
                        }
                    }
                    .padding(16)
                }

                controls
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: liveManager.lines.count) { _ in
            if let line = liveManager.lines.last {
                touchMessage = line.text
                emotion = line.role == .assistant ? .happy : .thinking
            }
        }
        .onChange(of: liveManager.errorText) { message in
            if let message, !message.isEmpty { touchMessage = message }
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            if speaking { emotion = .happy }
        }
        .onDisappear { liveManager.end() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ChatAI Companion")
                    .font(.headline)
                Text(viewModel.selectedProvider.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showConversation.toggle()
                }
            } label: {
                Image(systemName: showConversation ? "text.bubble" : "text.bubble.fill")
                    .font(.title3)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Ẩn hoặc hiện hội thoại")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var conversationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lastUser = viewModel.messages.last(where: { $0.role == .user }) {
                Text("ANH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(lastUser.content)
                    .font(.subheadline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let lastReply = viewModel.messages.last(where: { $0.role == .assistant }) {
                Text("CHATAI")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cyan.opacity(0.9))
                Text(lastReply.content)
                    .font(.subheadline)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.isSending {
                Label("Đang suy nghĩ...", systemImage: "sparkles")
                    .font(.subheadline)
            } else if viewModel.messages.isEmpty {
                Text("Chào anh! Mình trò chuyện nhé.")
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button {
                    if liveManager.state == .idle {
                        startGeminiLive()
                    } else {
                        liveManager.end()
                        isVoiceChatActive = false
                    }
                } label: {
                    Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                        .background(liveManager.state == .idle ? .white.opacity(0.12) : .red.opacity(0.8), in: Circle())
                }
                .accessibilityLabel(liveManager.state == .idle ? "Bắt đầu Gemini Live" : "Kết thúc Gemini Live")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showConversation = true
                        isVoiceChatActive = true
                    }
                    if liveManager.state == .idle { startGeminiLive() }
                } label: {
                    Label(liveManager.state == .live ? (liveManager.aiSpeaking ? "AI đang nói..." : "Đang nghe anh") : (liveManager.state == .connecting ? "Đang kết nối Gemini..." : "Tiếp tục chat"), systemImage: "waveform")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 50, height: 50)
                        .background(.red.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Đóng màn hình companion")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.black.opacity(0.22))
    }

    private func startGeminiLive() {
        isVoiceChatActive = true
        showConversation = true
        liveManager.start(model: liveModel, voice: liveVoice, persona: livePersona, bargeIn: liveBargeIn)
    }

    private enum TouchTarget { case head, cheek, body }

    private func reactToTouch(_ target: TouchTarget) {
        let prompt: String
        switch target {
        case .head:
            prompt = "Anh vừa chạm nhẹ vào đầu em. Hãy phản ứng ấm áp, tự nhiên bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."
            emotion = .happy
        case .cheek:
            prompt = "Anh vừa chạm nhẹ vào má em. Hãy phản ứng hơi ngại ngùng, dễ thương bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."
            emotion = .shy
        case .body:
            prompt = "Anh vừa chạm vào em để gọi em. Hãy phản ứng vui vẻ, tự nhiên bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."
            emotion = .surprised
        }
        if liveManager.state == .live {
            liveManager.sendText(prompt)
            touchMessage = nil
        } else {
            touchMessage = "Bấm “Tiếp tục chat” để kết nối Gemini Live trước nhé."
        }
    }

    private var emotionName: String {
        switch emotion {
        case .idle: return "idle"
        case .happy: return "happy"
        case .thinking: return "thinking"
        case .shy: return "shy"
        case .surprised: return "surprised"
        }
    }

    private var statusText: String {
        switch emotion {
        case .idle: return "Đang ở đây với anh"
        case .happy: return "Em đang vui"
        case .thinking: return "Đang suy nghĩ"
        case .shy: return "Em hơi ngại..."
        case .surprised: return "Ơ, bất ngờ quá!"
        }
    }

    private var statusSymbol: String {
        switch emotion {
        case .idle: return "sparkles"
        case .happy: return "face.smiling"
        case .thinking: return "ellipsis.bubble"
        case .shy: return "heart.fill"
        case .surprised: return "exclamationmark.bubble"
        }
    }
}

private enum CompanionEmotion {
    case idle, happy, thinking, shy, surprised
}


/// SceneKit-based 3D chibi companion stage. Procedural model is used until the licensed VRM asset is bundled.
private struct Companion3DStage: UIViewRepresentable {
    let emotion: String
    let isNight: Bool
    let isSpeaking: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = makeScene()
        view.backgroundColor = .clear
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let scene = view.scene, let character = scene.rootNode.childNode(withName: "companionRoot", recursively: true) else { return }
        character.childNode(withName: "head", recursively: true)?.eulerAngles.z = emotion == "shy" ? 0.12 : 0
        character.childNode(withName: "mouth", recursively: true)?.scale.y = isSpeaking ? 2.8 : (emotion == "surprised" ? 2.2 : 1.0)
        scene.background.contents = UIColor.clear
        scene.rootNode.childNode(withName: "environmentGlow", recursively: true)?.geometry?.firstMaterial?.diffuse.contents =
            (isNight ? UIColor(red: 0.36, green: 0.43, blue: 0.92, alpha: 0.28) : UIColor(red: 1, green: 0.70, blue: 0.48, alpha: 0.25))
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = UIColor(white: 0.8, alpha: 1)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.65, 7.8)
        cameraNode.look(at: SCNVector3(0, 1.45, 0))
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 850
        key.position = SCNVector3(-3, 5, 5)
        scene.rootNode.addChildNode(key)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 500
        fill.position = SCNVector3(3, 2, 2)
        scene.rootNode.addChildNode(fill)

        let root = SCNNode()
        root.name = "companionRoot"
        scene.rootNode.addChildNode(root)

        func material(_ color: UIColor, roughness: CGFloat = 0.48, metallic: CGFloat = 0) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.roughness.contents = roughness
            m.metalness.contents = metallic
            return m
        }
        let skin = material(UIColor(red: 1, green: 0.77, blue: 0.69, alpha: 1))
        let hair = material(UIColor(red: 0.12, green: 0.075, blue: 0.19, alpha: 1), roughness: 0.3)
        let hairLight = material(UIColor(red: 0.29, green: 0.18, blue: 0.39, alpha: 1), roughness: 0.3)
        let dress = material(UIColor(red: 0.43, green: 0.34, blue: 0.78, alpha: 1))
        let white = material(.white)
        let iris = material(UIColor(red: 0.44, green: 0.28, blue: 0.76, alpha: 1), roughness: 0.2)
        let black = material(UIColor(red: 0.12, green: 0.07, blue: 0.15, alpha: 1))
        let pink = material(UIColor(red: 1, green: 0.35, blue: 0.59, alpha: 1))

        func sphere(_ name: String, _ radius: CGFloat, _ position: SCNVector3, _ mat: SCNMaterial, scale: SCNVector3? = nil) -> SCNNode {
            let g = SCNSphere(radius: radius)
            g.segmentCount = 24
            g.firstMaterial = mat
            let n = SCNNode(geometry: g)
            n.name = name
            n.position = position
            if let scale { n.scale = scale }
            root.addChildNode(n)
            return n
        }
        func capsule(_ name: String, radius: CGFloat, height: CGFloat, position: SCNVector3, mat: SCNMaterial) -> SCNNode {
            let n = SCNNode(geometry: SCNCapsule(capRadius: radius, height: height))
            n.name = name
            n.position = position
            n.geometry?.firstMaterial = mat
            root.addChildNode(n)
            return n
        }

        // Oversized head, layered hair, large anime eyes, and a compact outfit.
        sphere("body", 0.53, SCNVector3(0, 0.72, 0), dress, scale: SCNVector3(0.88, 1.25, 0.7))
        capsule("neck", radius: 0.13, height: 0.28, position: SCNVector3(0, 1.28, 0), mat: skin)
        let head = sphere("head", 0.82, SCNVector3(0, 2.02, 0), skin, scale: SCNVector3(0.92, 1.05, 0.78))
        sphere("backHair", 0.86, SCNVector3(0, 2.12, -0.12), hair, scale: SCNVector3(1.05, 1.12, 0.88)).renderingOrder = -1
        sphere("fringe", 0.55, SCNVector3(0, 2.52, 0.35), hair, scale: SCNVector3(1.3, 0.48, 0.55))
        sphere("leftLock", 0.2, SCNVector3(-0.68, 1.86, 0.02), hair, scale: SCNVector3(0.8, 2.6, 0.8))
        sphere("rightLock", 0.2, SCNVector3(0.68, 1.86, 0.02), hair, scale: SCNVector3(0.8, 2.6, 0.8))
        sphere("hairShine", 0.07, SCNVector3(-0.34, 2.72, 0.69), hairLight, scale: SCNVector3(2.2, 0.5, 0.4))

        for x: Float in [-0.31, 0.31] {
            sphere("eyeWhite", 0.19, SCNVector3(x, 2.08, 0.69), white, scale: SCNVector3(0.82, 1.12, 0.3))
            sphere("iris", 0.13, SCNVector3(x, 2.07, 0.755), iris, scale: SCNVector3(0.82, 1.15, 0.3))
            sphere("pupil", 0.065, SCNVector3(x, 2.08, 0.79), black, scale: SCNVector3(0.8, 1.2, 0.3))
            sphere("eyeSparkle", 0.035, SCNVector3(x - 0.035, 2.13, 0.81), white)
        }
        sphere("blushL", 0.1, SCNVector3(-0.51, 1.87, 0.61), pink, scale: SCNVector3(1.3, 0.45, 0.25))
        sphere("blushR", 0.1, SCNVector3(0.51, 1.87, 0.61), pink, scale: SCNVector3(1.3, 0.45, 0.25))
        sphere("mouth", 0.055, SCNVector3(0, 1.83, 0.72), black, scale: SCNVector3(1.0, 0.65, 0.25))

        // Bow and dangling hair accessories.
        sphere("bowL", 0.15, SCNVector3(0.59, 2.75, 0.08), pink, scale: SCNVector3(1.2, 0.6, 0.45))
        sphere("bowR", 0.15, SCNVector3(0.81, 2.75, 0.08), pink, scale: SCNVector3(1.2, 0.6, 0.45))
        sphere("bowKnot", 0.07, SCNVector3(0.70, 2.75, 0.17), white)

        let leftArm = capsule("leftArm", radius: 0.12, height: 0.72, position: SCNVector3(-0.56, 0.85, 0.02), mat: dress)
        leftArm.eulerAngles.z = -0.45
        let rightArm = capsule("rightArm", radius: 0.12, height: 0.72, position: SCNVector3(0.56, 0.85, 0.02), mat: dress)
        rightArm.eulerAngles.z = 0.45
        capsule("leftLeg", radius: 0.14, height: 0.62, position: SCNVector3(-0.23, 0.08, 0.03), mat: skin)
        capsule("rightLeg", radius: 0.14, height: 0.62, position: SCNVector3(0.23, 0.08, 0.03), mat: skin)
        capsule("leftSock", radius: 0.15, height: 0.18, position: SCNVector3(-0.23, -0.20, 0.03), mat: white)
        capsule("rightSock", radius: 0.15, height: 0.18, position: SCNVector3(0.23, -0.20, 0.03), mat: white)

        let glow = SCNSphere(radius: 1.7)
        glow.firstMaterial = material(UIColor(red: 0.55, green: 0.63, blue: 1, alpha: 0.16))
        glow.firstMaterial?.isDoubleSided = true
        let glowNode = SCNNode(geometry: glow)
        glowNode.name = "environmentGlow"
        glowNode.position = SCNVector3(0, 1.55, -1.2)
        glowNode.scale = SCNVector3(1.05, 1.2, 0.1)
        root.addChildNode(glowNode)

        // Gentle breathing, floating, and arm sway animations.
        let breathe = SCNAction.repeatForever(.sequence([
            .scale(to: 1.025, duration: 1.8),
            .scale(to: 1.0, duration: 1.8)
        ]))
        root.runAction(breathe, forKey: "breathing")
        head.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: 0.035, duration: 1.6),
            .rotateTo(x: 0, y: 0, z: -0.035, duration: 1.6)
        ])), forKey: "headIdle")
        leftArm.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: -0.35, duration: 1.2),
            .rotateTo(x: 0, y: 0, z: -0.52, duration: 1.2)
        ])), forKey: "armSwayL")
        rightArm.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: 0.52, duration: 1.2),
            .rotateTo(x: 0, y: 0, z: 0.35, duration: 1.2)
        ])), forKey: "armSwayR")
        return scene
    }
}
