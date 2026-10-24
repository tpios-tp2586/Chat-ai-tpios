import SwiftUI
import UIKit
import SceneKit

/// ChatAI companion screen. The companion is intentionally a head-only 3D robot.
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
    @State private var touchMessage: String?
    @State private var isNight = Calendar.current.component(.hour, from: Date()) >= 19 || Calendar.current.component(.hour, from: Date()) < 6

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isNight
                    ? [Color(red: 0.025, green: 0.035, blue: 0.11), Color(red: 0.13, green: 0.08, blue: 0.22)]
                    : [Color(red: 0.08, green: 0.12, blue: 0.20), Color(red: 0.30, green: 0.19, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ZStack(alignment: .bottom) {
                    GeometryReader { geo in
                        Companion3DStage(
                            emotion: emotionName,
                            isNight: isNight,
                            isSpeaking: liveManager.aiSpeaking
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                let xRatio = value.location.x / max(geo.size.width, 1)
                                reactToTouch(xRatio < 0.38 || xRatio > 0.62 ? .cheek : .head)
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
                            Button { isNight.toggle() } label: {
                                Image(systemName: isNight ? "moon.stars.fill" : "sun.max.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        if let touchMessage {
                            Text(touchMessage)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if showConversation { conversationPreview }
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
            emotion = speaking ? .speaking : (emotion == .speaking ? .idle : emotion)
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
                Text("ChatAI Companion").font(.headline)
                Text(viewModel.selectedProvider.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { showConversation.toggle() }
            } label: {
                Image(systemName: showConversation ? "text.bubble" : "text.bubble.fill")
                    .font(.title3)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var conversationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lastUser = viewModel.messages.last(where: { $0.role == .user }) {
                Text("ANH").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                Text(lastUser.content).font(.subheadline).lineLimit(2)
            }
            if let lastReply = viewModel.messages.last(where: { $0.role == .assistant }) {
                Text("CHATAI").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.cyan.opacity(0.9))
                Text(lastReply.content).font(.subheadline).lineLimit(3)
            } else if viewModel.isSending {
                Label("Đang suy nghĩ...", systemImage: "sparkles").font(.subheadline)
            } else if viewModel.messages.isEmpty {
                Text("Chào anh! Mình trò chuyện nhé.").font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                if liveManager.state == .idle {
                    startGeminiLive()
                } else {
                    liveManager.end()
                }
            } label: {
                Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill")
                    .font(.title3)
                    .frame(width: 50, height: 50)
                    .background(liveManager.state == .idle ? .white.opacity(0.12) : .red.opacity(0.8), in: Circle())
            }

            Button {
                showConversation = true
                if liveManager.state == .idle { startGeminiLive() }
            } label: {
                Label(
                    liveManager.state == .live
                        ? (liveManager.aiSpeaking ? "AI đang nói..." : "Đang nghe anh")
                        : (liveManager.state == .connecting ? "Đang kết nối Gemini..." : "Tiếp tục chat"),
                    systemImage: "waveform"
                )
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
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.22))
    }

    private func startGeminiLive() {
        showConversation = true
        liveManager.start(model: liveModel, voice: liveVoice, persona: livePersona, bargeIn: liveBargeIn)
    }

    private enum TouchTarget { case head, cheek }

    private func reactToTouch(_ target: TouchTarget) {
        let prompt: String
        switch target {
        case .head:
            prompt = "Anh vừa chạm nhẹ vào đầu em. Hãy phản ứng ấm áp, tự nhiên bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."
            emotion = .happy
        case .cheek:
            prompt = "Anh vừa chạm nhẹ vào má em. Hãy phản ứng hơi ngại ngùng, dễ thương bằng tiếng Việt và trả lời bằng giọng nói ngay, chỉ một câu ngắn."
            emotion = .shy
        }
        if liveManager.state == .live {
            liveManager.sendText(prompt)
            touchMessage = nil
        } else {
            touchMessage = "Bấm 'Tiếp tục chat' để kết nối Gemini Live trước nhé."
        }
    }

    private var emotionName: String {
        switch emotion {
        case .idle: "idle"
        case .listening: "listening"
        case .thinking: "thinking"
        case .speaking: "speaking"
        case .happy: "happy"
        case .surprised: "surprised"
        case .confused: "confused"
        case .sad: "sad"
        case .angry: "angry"
        case .sleepy: "sleepy"
        case .shy: "shy"
        }
    }

    private var statusText: String {
        switch emotion {
        case .idle: "Đang ở đây với anh"
        case .listening: "Em đang nghe anh"
        case .thinking: "Đang suy nghĩ"
        case .speaking: "Em đang nói"
        case .happy: "Em đang vui"
        case .surprised: "Ơ, bất ngờ quá!"
        case .confused: "Để em nghĩ lại..."
        case .sad: "Em hơi buồn..."
        case .angry: "Em đang giận đó nha"
        case .sleepy: "Em hơi buồn ngủ..."
        case .shy: "Em hơi ngại..."
        }
    }

    private var statusSymbol: String {
        switch emotion {
        case .idle: "sparkles"
        case .listening: "ear"
        case .thinking: "ellipsis.bubble"
        case .speaking: "waveform"
        case .happy: "face.smiling"
        case .surprised: "exclamationmark.bubble"
        case .confused: "questionmark.bubble"
        case .sad: "cloud.rain"
        case .angry: "flame"
        case .sleepy: "moon.zzz"
        case .shy: "heart.fill"
        }
    }
}

private enum CompanionEmotion {
    case idle, listening, thinking, speaking, happy, surprised, confused, sad, angry, sleepy, shy
}

/// Detailed head-only robot. No torso, arms, legs or clothing are generated.
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
        guard let scene = view.scene,
              let root = scene.rootNode.childNode(withName: "companionRoot", recursively: true) else { return }

        let expression = emotion
        let mouth = root.childNode(withName: "mouth", recursively: true)
        let mouthInner = root.childNode(withName: "mouthInner", recursively: true)
        let leftEye = root.childNode(withName: "eyeL", recursively: true)
        let rightEye = root.childNode(withName: "eyeR", recursively: true)
        let leftPupil = root.childNode(withName: "pupilL", recursively: true)
        let rightPupil = root.childNode(withName: "pupilR", recursively: true)
        let leftCheek = root.childNode(withName: "cheekL", recursively: true)
        let rightCheek = root.childNode(withName: "cheekR", recursively: true)
        let head = root.childNode(withName: "headShell", recursively: true)
        let antennaL = root.childNode(withName: "antennaTipL", recursively: true)
        let antennaR = root.childNode(withName: "antennaTipR", recursively: true)

        var eyeY: Float = 1.0
        var eyeX: Float = 1.0
        var pupilShift: Float = 0
        var mouthY: Float = 0.42
        var mouthX: Float = 1.0
        var headZ: Float = 0
        var cheekScale: Float = 1.0
        var glow: Float = 1.0

        switch expression {
        case "listening": eyeY = 1.08; pupilShift = 0.02; glow = 1.15
        case "thinking": pupilShift = -0.13; headZ = -0.035; mouthY = 0.30
        case "speaking": mouthY = 1.35; mouthX = 1.18; glow = 1.22
        case "happy": eyeY = 0.72; mouthX = 1.45; mouthY = 0.55; cheekScale = 1.25
        case "surprised": eyeY = 1.28; eyeX = 1.12; mouthY = 1.45; mouthX = 0.80; glow = 1.28
        case "confused": pupilShift = -0.10; headZ = 0.08; mouthX = 0.72
        case "sad": eyeY = 0.82; pupilShift = 0.02; mouthY = 0.22; headZ = -0.05
        case "angry": eyeY = 0.62; eyeX = 0.92; mouthY = 0.28; headZ = 0.02
        case "sleepy": eyeY = 0.30; mouthY = 0.25; glow = 0.75
        case "shy": eyeY = 0.80; pupilShift = 0.02; cheekScale = 1.55; headZ = 0.04
        default: break
        }

        if isSpeaking {
            mouthY = max(mouthY, 1.25)
        }

        setScaleY(leftEye, eyeY)
        setScaleY(rightEye, eyeY)
        setScaleX(leftEye, eyeX)
        setScaleX(rightEye, eyeX)
        leftPupil?.position.x = -0.54 + pupilShift
        rightPupil?.position.x = 0.54 + pupilShift
        setScaleX(mouth, mouthX)
        setScaleY(mouth, mouthY)
        setScaleY(mouthInner, mouthY)
        setScaleX(leftCheek, cheekScale)
        setScaleX(rightCheek, cheekScale)
        head?.eulerAngles.z = headZ
        head?.eulerAngles.y = expression == "thinking" ? -0.06 : 0
        antennaL?.scale = SCNVector3(repeating: glow)
        antennaR?.scale = SCNVector3(repeating: glow)

        if let material = root.childNode(withName: "eyeL", recursively: true)?.geometry?.firstMaterial {
            material.emission.contents = UIColor(red: 0.05, green: 0.92, blue: 1, alpha: 1)
        }

        scene.rootNode.childNode(withName: "environmentGlow", recursively: true)?.geometry?.firstMaterial?.diffuse.contents =
            isNight
                ? UIColor(red: 0.20, green: 0.35, blue: 1.0, alpha: 0.22)
                : UIColor(red: 1.0, green: 0.62, blue: 0.80, alpha: 0.18)
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let camera = SCNCamera()
        camera.fieldOfView = 29
        camera.zNear = 0.1
        camera.zFar = 80
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.15, 8.8)
        cameraNode.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(cameraNode)

        addLight(to: scene, type: .omni, intensity: 1150,
                 color: UIColor(red: 1, green: 0.90, blue: 0.96, alpha: 1),
                 position: SCNVector3(-4, 4, 5))
        addLight(to: scene, type: .omni, intensity: 900,
                 color: UIColor(red: 0.28, green: 0.88, blue: 1, alpha: 1),
                 position: SCNVector3(4, 1, 5))
        addLight(to: scene, type: .omni, intensity: 650,
                 color: UIColor(red: 1, green: 0.34, blue: 0.68, alpha: 1),
                 position: SCNVector3(0, -3, 3))

        let root = SCNNode()
        root.name = "companionRoot"
        scene.rootNode.addChildNode(root)

        let pearl = mat(UIColor(red: 0.96, green: 0.985, blue: 1.0, alpha: 1), rough: 0.20, metal: 0.10)
        let pink = mat(UIColor(red: 1.0, green: 0.56, blue: 0.76, alpha: 1), rough: 0.22, metal: 0.08)
        let pinkLight = mat(UIColor(red: 1.0, green: 0.78, blue: 0.88, alpha: 1), rough: 0.25)
        let blue = mat(UIColor(red: 0.40, green: 0.86, blue: 1.0, alpha: 1), rough: 0.18, metal: 0.05)
        let visor = mat(UIColor(red: 0.006, green: 0.012, blue: 0.025, alpha: 1), rough: 0.08, metal: 0.42)
        let cyan = mat(UIColor(red: 0.08, green: 0.95, blue: 1.0, alpha: 1), rough: 0.12)
        cyan.emission.contents = UIColor(red: 0.02, green: 0.82, blue: 1.0, alpha: 1)
        let cyanDark = mat(UIColor(red: 0.02, green: 0.38, blue: 0.58, alpha: 1), rough: 0.16)
        let white = mat(.white, rough: 0.08)
        let mouthMat = mat(UIColor(red: 1.0, green: 0.32, blue: 0.67, alpha: 1), rough: 0.18)
        mouthMat.emission.contents = UIColor(red: 1.0, green: 0.12, blue: 0.48, alpha: 1)

        // Ambient glow behind the robot head.
        let halo = sphere(root, "environmentGlow", radius: 2.35,
                          position: SCNVector3(0, 0.05, -1.05),
                          material: mat(UIColor(red: 0.30, green: 0.78, blue: 1.0, alpha: 0.16), rough: 1),
                          scale: SCNVector3(1.22, 0.92, 0.10), segments: 64)
        halo.geometry?.firstMaterial?.lightingModel = .constant

        // Decorative side ears/fins. These stay attached to the head; there is no body.
        makeEar(root: root, side: -1, pink: pink, blue: blue, white: white)
        makeEar(root: root, side: 1, pink: pink, blue: blue, white: white)

        // Outer pastel-pink rounded shell.
        let outerGeo = SCNBox(width: 3.35, height: 2.72, length: 1.60, chamferRadius: 0.56)
        outerGeo.widthSegmentCount = 10
        outerGeo.heightSegmentCount = 10
        outerGeo.lengthSegmentCount = 8
        outerGeo.firstMaterial = pink
        let outer = SCNNode(geometry: outerGeo)
        outer.name = "headRim"
        outer.position = SCNVector3(0, 0.12, 0)
        root.addChildNode(outer)

        // Pearl-white inner shell creates a real visible pink rim around the entire head.
        let shellGeo = SCNBox(width: 3.18, height: 2.55, length: 1.50, chamferRadius: 0.52)
        shellGeo.widthSegmentCount = 10
        shellGeo.heightSegmentCount = 10
        shellGeo.lengthSegmentCount = 8
        shellGeo.firstMaterial = pearl
        let shell = SCNNode(geometry: shellGeo)
        shell.name = "headShell"
        shell.position = SCNVector3(0, 0.13, 0.08)
        root.addChildNode(shell)

        // Top crown panel and small pink seam, matching the reference's soft toy-like construction.
        let crown = roundedBox(root, name: "crown", width: 2.72, height: 0.62, length: 1.34,
                               radius: 0.28, position: SCNVector3(0, 1.17, 0.15), material: pearl)
        crown.eulerAngles.x = -0.04
        roundedBox(root, name: "crownBand", width: 2.74, height: 0.10, length: 1.38,
                   radius: 0.05, position: SCNVector3(0, 0.90, 0.22), material: pinkLight)

        // Two short antenna stems and glossy pink tips.
        for (x, suffix) in [(-0.54, "L"), (0.54, "R")] as [(Float, String)] {
            let stemGeo = SCNCylinder(radius: 0.045, height: 0.44)
            stemGeo.firstMaterial = blue
            let stem = SCNNode(geometry: stemGeo)
            stem.name = "antennaStem" + suffix
            stem.position = SCNVector3(x, 1.72, 0.10)
            stem.eulerAngles.z = x < 0 ? -0.17 : 0.17
            root.addChildNode(stem)

            let tip = sphere(root, "antennaTip" + suffix, radius: 0.145,
                             position: SCNVector3(x * 1.10, 1.98, 0.12), material: pink, segments: 36)
            tip.geometry?.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.30, blue: 0.66, alpha: 1)
            sphere(root, "antennaHighlight" + suffix, radius: 0.048,
                   position: SCNVector3(x * 1.10 - 0.035, 2.03, 0.25), material: white, segments: 16)
        }

        // Large glossy black visor inset into the shell.
        let visorOuter = roundedBox(root, name: "visorFrame", width: 2.86, height: 1.76, length: 0.24,
                                    radius: 0.40, position: SCNVector3(0, 0.13, 0.87), material: pinkLight)
        visorOuter.scale = SCNVector3(1.01, 1.01, 1)
        roundedBox(root, name: "visor", width: 2.70, height: 1.60, length: 0.20,
                   radius: 0.36, position: SCNVector3(0, 0.13, 1.01), material: visor)

        // Glass reflection across the upper-left of the visor.
        let reflection = roundedBox(root, name: "visorReflection", width: 0.72, height: 0.16, length: 0.035,
                                     radius: 0.08, position: SCNVector3(-0.82, 0.72, 1.13), material: white)
        reflection.eulerAngles.z = -0.42
        reflection.opacity = 0.28

        // Detailed cyan eyes: outer glow, luminous oval, iris, pupil and two highlights.
        for (x, suffix) in [(-0.56, "L"), (0.56, "R")] as [(Float, String)] {
            sphere(root, "eyeGlow" + suffix, radius: 0.37,
                   position: SCNVector3(x, 0.17, 1.14), material: cyanDark,
                   scale: SCNVector3(0.88, 1.18, 0.16), segments: 48)

            let eye = sphere(root, "eye" + suffix, radius: 0.31,
                             position: SCNVector3(x, 0.17, 1.20), material: cyan,
                             scale: SCNVector3(0.83, 1.18, 0.22), segments: 48)
            eye.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.03, green: 0.92, blue: 1, alpha: 1)

            sphere(root, "iris" + suffix, radius: 0.145,
                   position: SCNVector3(x, 0.15, 1.28), material: cyanDark,
                   scale: SCNVector3(0.94, 1.08, 0.24), segments: 36)
            sphere(root, "pupil" + suffix, radius: 0.085,
                   position: SCNVector3(x, 0.15, 1.32), material: visor,
                   scale: SCNVector3(0.88, 1.08, 0.24), segments: 32)
            sphere(root, "sparkle" + suffix, radius: 0.075,
                   position: SCNVector3(x - 0.075, 0.29, 1.37), material: white, segments: 20)
            sphere(root, "sparkleSmall" + suffix, radius: 0.032,
                   position: SCNVector3(x + 0.075, 0.06, 1.37), material: white, segments: 14)
        }

        // Pink cheeks, positioned inside the visor for the same cute visual language as the reference.
        for x in [-0.92, 0.92] as [Float] {
            let name = x < 0 ? "cheekL" : "cheekR"
            let cheek = sphere(root, name, radius: 0.13,
                               position: SCNVector3(x, -0.37, 1.16), material: pinkLight,
                               scale: SCNVector3(1.35, 0.50, 0.16), segments: 32)
            cheek.geometry?.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.32, blue: 0.62, alpha: 1)
        }

        // Tiny smiling mouth, built from an outer pink lip and dark inner opening.
        let mouth = roundedBox(root, name: "mouth", width: 0.42, height: 0.16, length: 0.10,
                               radius: 0.07, position: SCNVector3(0, -0.35, 1.19), material: mouthMat)
        mouth.scale = SCNVector3(1.0, 0.42, 1.0)
        roundedBox(root, name: "mouthInner", width: 0.24, height: 0.08, length: 0.025,
                   radius: 0.035, position: SCNVector3(0, -0.35, 1.255), material: visor)

        // Side fin layers add the soft wing-like silhouette from the reference without creating a body.
        makeSideFin(root: root, side: -1, pink: pink, blue: blue, white: white)
        makeSideFin(root: root, side: 1, pink: pink, blue: blue, white: white)

        // Gentle idle motion. All geometry remains a single head-only companion.
        root.runAction(.repeatForever(.sequence([
            .customAction(withDuration: 1.8) { node, elapsed in
                let p = Float(elapsed / 1.8)
                node.position.y = sin(p * .pi * 2) * 0.018
            },
            .customAction(withDuration: 1.8) { node, elapsed in
                let p = Float(elapsed / 1.8)
                node.position.y = sin((1 - p) * .pi * 2) * 0.018
            }
        ])), forKey: "idleFloat")

        return scene
    }

    private func makeEar(root: SCNNode, side: Float, pink: SCNMaterial, blue: SCNMaterial, white: SCNMaterial) {
        let x = side * 1.70
        let ear = sphere(root, side < 0 ? "earL" : "earR", radius: 0.42,
                         position: SCNVector3(x, 0.12, 0.08), material: pink,
                         scale: SCNVector3(0.58, 1.0, 0.48), segments: 40)
        ear.eulerAngles.z = side < 0 ? -0.12 : 0.12
        sphere(root, side < 0 ? "earBlueL" : "earBlueR", radius: 0.27,
               position: SCNVector3(x - side * 0.03, 0.12, 0.30), material: blue,
               scale: SCNVector3(0.52, 0.98, 0.30), segments: 32)
        sphere(root, side < 0 ? "earWhiteL" : "earWhiteR", radius: 0.08,
               position: SCNVector3(x + side * 0.02, 0.27, 0.42), material: white,
               scale: SCNVector3(0.65, 0.65, 0.30), segments: 20)
    }

    private func makeSideFin(root: SCNNode, side: Float, pink: SCNMaterial, blue: SCNMaterial, white: SCNMaterial) {
        let x = side * 1.72
        for i in 0..<3 {
            let y = 0.48 - Float(i) * 0.38
            let fin = sphere(root, "fin_\(side < 0 ? "L" : "R")_\(i)", radius: 0.33,
                             position: SCNVector3(x + side * Float(i) * 0.08, y, -0.04),
                             material: i == 1 ? blue : pink,
                             scale: SCNVector3(0.28, 0.88, 0.42), segments: 32)
            fin.eulerAngles.z = side * (-0.28 + Float(i) * 0.20)
            if i == 1 {
                sphere(root, "finHighlight_\(side < 0 ? "L" : "R")_\(i)", radius: 0.045,
                       position: SCNVector3(x + side * 0.01, y + 0.12, 0.22), material: white, segments: 12)
            }
        }
    }

    private func roundedBox(_ parent: SCNNode, name: String, width: CGFloat, height: CGFloat, length: CGFloat,
                            radius: CGFloat, position: SCNVector3, material: SCNMaterial) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        geometry.widthSegmentCount = 10
        geometry.heightSegmentCount = 10
        geometry.lengthSegmentCount = 8
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = position
        parent.addChildNode(node)
        return node
    }

    @discardableResult
    private func sphere(_ parent: SCNNode, _ name: String, radius: CGFloat, position: SCNVector3,
                        material: SCNMaterial, scale: SCNVector3? = nil, segments: Int = 48) -> SCNNode {
        let geometry = SCNSphere(radius: radius)
        geometry.segmentCount = segments
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = position
        if let scale { node.scale = scale }
        parent.addChildNode(node)
        return node
    }

    private func setScaleX(_ node: SCNNode?, _ value: Float) {
        guard let node else { return }
        node.scale.x = value
    }

    private func setScaleY(_ node: SCNNode?, _ value: Float) {
        guard let node else { return }
        node.scale.y = value
    }

    private func mat(_ color: UIColor, rough: CGFloat = 0.48, metal: CGFloat = 0) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = rough
        material.metalness.contents = metal
        material.lightingModel = .physicallyBased
        return material
    }

    private func addLight(to scene: SCNScene, type: SCNLight.LightType, intensity: CGFloat,
                          color: UIColor, position: SCNVector3) {
        let light = SCNLight()
        light.type = type
        light.intensity = intensity
        light.color = color
        let node = SCNNode()
        node.light = light
        node.position = position
        scene.rootNode.addChildNode(node)
    }
}