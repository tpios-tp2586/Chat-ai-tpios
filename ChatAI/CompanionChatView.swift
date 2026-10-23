import SwiftUI
import UIKit
import SceneKit

/// Anime companion screen with a procedural SceneKit 3D stage and Gemini Live voice interaction.
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
            touchMessage = "Bấm 'Tiếp tục chat' để kết nối Gemini Live trước nhé."
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


/// SceneKit-based 3D anime companion stage.
/// Procedural model is used until the licensed VRM asset (CompanionChibi.usdz) is bundled.
/// Changes vs previous version:
///   - Head smaller (0.62), torso taller + narrower → mature anime proportion
///   - Skin tone warmer, hair deep burgundy with specular sheen
///   - Dress replaced with dark navy + crimson accent, proper SCNCone skirt flare
///   - Eyelashes added as thin SCNBox planes above each eye
///   - Rim light (cyan) added behind character for depth separation
///   - segmentCount raised to 48 on all spheres → smoother silhouette
///   - Floating animation offset so character sits slightly higher in frame
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
              let character = scene.rootNode.childNode(withName: "companionRoot", recursively: true) else { return }

        let head = character.childNode(withName: "head", recursively: true)
        head?.eulerAngles.z = emotion == "shy" ? 0.14 : (emotion == "thinking" ? -0.11 : 0)
        head?.eulerAngles.y = emotion == "thinking" ? -0.13 : 0

        let mouth = character.childNode(withName: "mouth", recursively: true)
        mouth?.scale.y = isSpeaking ? 3.2 : (emotion == "surprised" ? 2.5 : 1.0)
        mouth?.scale.x = emotion == "happy" ? 1.8 : 1.0

        for suffix in ["L", "R"] {
            character.childNode(withName: "iris" + suffix, recursively: true)?.position.x =
                Float(suffix == "L" ? -0.285 : 0.285) + Float(emotion == "thinking" ? -0.04 : 0)
        }

        scene.background.contents = UIColor.clear
        scene.rootNode.childNode(withName: "environmentGlow", recursively: true)?
            .geometry?.firstMaterial?.diffuse.contents =
            isNight
                ? UIColor(red: 0.30, green: 0.38, blue: 0.95, alpha: 0.22)
                : UIColor(red: 0.95, green: 0.65, blue: 0.40, alpha: 0.20)
    }

    // MARK: - Scene construction

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = UIColor(white: 0.75, alpha: 1)

        // ── Camera ──────────────────────────────────────────────────────────
        let camera = SCNCamera()
        camera.fieldOfView = 32          // slightly tighter → less distortion
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.72, 7.4)
        cameraNode.look(at: SCNVector3(0, 1.55, 0))
        scene.rootNode.addChildNode(cameraNode)

        // ── Lighting ────────────────────────────────────────────────────────
        // Key light — warm, from upper-left front
        addLight(to: scene, type: .omni,        intensity: 900,
                 color: UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1),
                 position: SCNVector3(-3, 5.5, 5))
        // Fill light — cool, right side
        addLight(to: scene, type: .omni,        intensity: 420,
                 color: UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1),
                 position: SCNVector3(3.5, 2.5, 2))
        // Rim light — cyan, behind character → separates from background
        addLight(to: scene, type: .omni,        intensity: 320,
                 color: UIColor(red: 0.30, green: 0.95, blue: 1.0, alpha: 1),
                 position: SCNVector3(0, 2.8, -4.5))
        // Bottom ambient bounce
        addLight(to: scene, type: .ambient,     intensity: 180,
                 color: UIColor(red: 0.55, green: 0.50, blue: 0.70, alpha: 1),
                 position: SCNVector3(0, -1, 0))

        // ── Prefer bundled USDZ when available ──────────────────────────────
        if let modelURL = Bundle.main.url(forResource: "CompanionChibi", withExtension: "usdz"),
           let importedScene = try? SCNScene(url: modelURL, options: nil) {
            let importedRoot = SCNNode()
            importedRoot.name = "companionRoot"
            for child in importedScene.rootNode.childNodes {
                importedRoot.addChildNode(child.clone())
            }
            let bounds   = importedRoot.boundingBox
            let height   = max(bounds.max.y - bounds.min.y, 0.001)
            let scale    = Float(2.8) / height
            importedRoot.scale     = SCNVector3(scale, scale, scale)
            importedRoot.position.y = -((bounds.min.y + bounds.max.y) * 0.5) * scale + 1.4
            scene.rootNode.addChildNode(importedRoot)
            return scene
        }

        // ── Procedural fallback ─────────────────────────────────────────────
        let root = SCNNode()
        root.name = "companionRoot"
        scene.rootNode.addChildNode(root)

        // Materials
        let skin     = mat(UIColor(red: 0.98, green: 0.82, blue: 0.74, alpha: 1), rough: 0.55)
        let hair     = mat(UIColor(red: 0.22, green: 0.06, blue: 0.10, alpha: 1), rough: 0.25, metal: 0.05)
        let hairShim = mat(UIColor(red: 0.52, green: 0.18, blue: 0.28, alpha: 1), rough: 0.18, metal: 0.10)
        // Elegant dark navy dress with slight sheen
        let dress    = mat(UIColor(red: 0.08, green: 0.10, blue: 0.26, alpha: 1), rough: 0.38, metal: 0.08)
        let accent   = mat(UIColor(red: 0.76, green: 0.10, blue: 0.22, alpha: 1), rough: 0.30)
        let white    = mat(.white, rough: 0.60)
        let iris     = mat(UIColor(red: 0.38, green: 0.22, blue: 0.72, alpha: 1), rough: 0.15, metal: 0.05)
        let black    = mat(UIColor(red: 0.08, green: 0.04, blue: 0.10, alpha: 1), rough: 0.70)
        let pink     = mat(UIColor(red: 0.98, green: 0.45, blue: 0.62, alpha: 1), rough: 0.50)
        let lash     = mat(UIColor(red: 0.05, green: 0.02, blue: 0.08, alpha: 1), rough: 0.80)

        // ── Body structure (mature proportion: smaller head, longer torso) ──
        // Torso — slender, taller
        let torsoGeo = SCNCapsule(capRadius: 0.38, height: 1.10)
        torsoGeo.radialSegmentCount = 48
        torsoGeo.firstMaterial = dress
        let torso = SCNNode(geometry: torsoGeo)
        torso.name = "torso"
        torso.position = SCNVector3(0, 0.82, 0)
        torso.scale = SCNVector3(0.80, 1.0, 0.62)
        root.addChildNode(torso)

        // Skirt flare — SCNCone, wider at bottom
        let skirtGeo = SCNCone(topRadius: 0.30, bottomRadius: 0.72, height: 0.55)
        skirtGeo.radialSegmentCount = 48
        skirtGeo.firstMaterial = dress
        let skirt = SCNNode(geometry: skirtGeo)
        skirt.name = "skirt"
        skirt.position = SCNVector3(0, 0.26, 0)
        root.addChildNode(skirt)

        // Skirt accent trim at hem
        let trimGeo = SCNCylinder(radius: 0.73, height: 0.045)
        trimGeo.radialSegmentCount = 48
        trimGeo.firstMaterial = accent
        let trim = SCNNode(geometry: trimGeo)
        trim.position = SCNVector3(0, -0.03, 0)
        root.addChildNode(trim)

        // Neck
        let neckGeo = SCNCapsule(capRadius: 0.095, height: 0.26)
        neckGeo.radialSegmentCount = 32
        neckGeo.firstMaterial = skin
        let neck = SCNNode(geometry: neckGeo)
        neck.name = "neck"
        neck.position = SCNVector3(0, 1.42, 0)
        root.addChildNode(neck)

        // Head — smaller ratio for mature look
        let headGeo = SCNSphere(radius: 0.62)
        headGeo.segmentCount = 48
        headGeo.firstMaterial = skin
        let head = SCNNode(geometry: headGeo)
        head.name = "head"
        head.position = SCNVector3(0, 2.10, 0)
        head.scale = SCNVector3(0.93, 1.04, 0.80)
        root.addChildNode(head)

        // ── Hair ────────────────────────────────────────────────────────────
        sphere(root, "backHair",  r: 0.66, p: SCNVector3(0, 2.18, -0.10), m: hair,
               s: SCNVector3(1.08, 1.14, 0.90), seg: 48).renderingOrder = -1
        sphere(root, "fringe",    r: 0.42, p: SCNVector3(0, 2.58, 0.30),  m: hair,
               s: SCNVector3(1.35, 0.44, 0.52), seg: 48)
        sphere(root, "leftLock",  r: 0.16, p: SCNVector3(-0.56, 1.92, 0.02), m: hair,
               s: SCNVector3(0.82, 2.80, 0.78), seg: 32)
        sphere(root, "rightLock", r: 0.16, p: SCNVector3( 0.56, 1.92, 0.02), m: hair,
               s: SCNVector3(0.82, 2.80, 0.78), seg: 32)
        // Hair specular sheen highlight
        sphere(root, "hairShine", r: 0.055, p: SCNVector3(-0.28, 2.68, 0.55), m: hairShim,
               s: SCNVector3(2.4, 0.44, 0.36), seg: 24)

        // ── Eyes ────────────────────────────────────────────────────────────
        let eyeData: [(x: Float, sfx: String)] = [(-0.285, "L"), (0.285, "R")]
        for (x, sfx) in eyeData {
            let ew = sphere(root, "eyeWhite"+sfx, r: 0.155,
                            p: SCNVector3(x, 2.14, 0.52), m: white,
                            s: SCNVector3(0.84, 1.18, 0.28), seg: 48)
            let ei = sphere(root, "iris"+sfx, r: 0.108,
                            p: SCNVector3(x, 2.13, 0.565), m: iris,
                            s: SCNVector3(0.84, 1.22, 0.28), seg: 48)
            sphere(root, "pupil"+sfx, r: 0.055,
                   p: SCNVector3(x, 2.14, 0.590), m: black,
                   s: SCNVector3(0.82, 1.26, 0.28), seg: 32)
            sphere(root, "sparkle"+sfx, r: 0.028,
                   p: SCNVector3(x - 0.028, 2.19, 0.608), m: white, seg: 16)

            // Eyelash — thin SCNBox plane above each eye
            let lashGeo = SCNBox(width: 0.32, height: 0.045, length: 0.025, chamferRadius: 0)
            lashGeo.firstMaterial = lash
            let lashNode = SCNNode(geometry: lashGeo)
            lashNode.name = "lash" + sfx
            lashNode.position = SCNVector3(x, 2.205, 0.545)
            lashNode.eulerAngles.x = -0.12
            root.addChildNode(lashNode)

            // Blink action
            let blinkSeq = SCNAction.sequence([
                .wait(duration: 3.1),
                .customAction(duration: 0.06) { n, _ in n.scale.y = 0.06 },
                .customAction(duration: 0.10) { n, _ in n.scale.y = n.name?.hasPrefix("eyeWhite") == true ? 1.18 : 1.22 }
            ])
            ew.runAction(.repeatForever(blinkSeq), forKey: "blink")
            ei.runAction(.repeatForever(blinkSeq), forKey: "blink")
        }

        // Blush
        sphere(root, "blushL", r: 0.08, p: SCNVector3(-0.44, 1.95, 0.48), m: pink,
               s: SCNVector3(1.35, 0.40, 0.22), seg: 24)
        sphere(root, "blushR", r: 0.08, p: SCNVector3( 0.44, 1.95, 0.48), m: pink,
               s: SCNVector3(1.35, 0.40, 0.22), seg: 24)

        // Mouth — small and refined
        sphere(root, "mouth", r: 0.042, p: SCNVector3(0, 1.90, 0.57), m: black,
               s: SCNVector3(1.0, 0.55, 0.22), seg: 24)

        // ── Accessories ─────────────────────────────────────────────────────
        // Choker accent
        let chokerGeo = SCNCylinder(radius: 0.098, height: 0.055)
        chokerGeo.radialSegmentCount = 32
        chokerGeo.firstMaterial = accent
        let choker = SCNNode(geometry: chokerGeo)
        choker.position = SCNVector3(0, 1.42, 0)
        choker.eulerAngles.x = Float.pi / 2
        root.addChildNode(choker)

        // Hair clip / ribbon (replaces the pink blob pin)
        sphere(root, "ribbonL",   r: 0.10, p: SCNVector3( 0.50, 2.66, 0.10), m: accent,
               s: SCNVector3(1.25, 0.55, 0.40), seg: 24)
        sphere(root, "ribbonR",   r: 0.10, p: SCNVector3( 0.72, 2.66, 0.10), m: accent,
               s: SCNVector3(1.25, 0.55, 0.40), seg: 24)
        sphere(root, "ribbonKnot",r: 0.048, p: SCNVector3(0.61, 2.66, 0.18), m: white, seg: 16)

        // ── Arms ────────────────────────────────────────────────────────────
        let leftArm  = capsule(root, "leftArm",  cr: 0.095, h: 0.68,
                               p: SCNVector3(-0.50, 0.88, 0.02), m: dress)
        leftArm.eulerAngles.z = -0.38
        let rightArm = capsule(root, "rightArm", cr: 0.095, h: 0.68,
                               p: SCNVector3( 0.50, 0.88, 0.02), m: dress)
        rightArm.eulerAngles.z = 0.38

        // Hands (small skin spheres)
        sphere(root, "handL", r: 0.09, p: SCNVector3(-0.78, 0.58, 0.02), m: skin, seg: 32)
        sphere(root, "handR", r: 0.09, p: SCNVector3( 0.78, 0.58, 0.02), m: skin, seg: 32)

        // ── Legs & shoes ────────────────────────────────────────────────────
        capsule(root, "leftLeg",   cr: 0.11, h: 0.58, p: SCNVector3(-0.20, 0.02, 0.02), m: skin)
        capsule(root, "rightLeg",  cr: 0.11, h: 0.58, p: SCNVector3( 0.20, 0.02, 0.02), m: skin)

        // Knee-high socks
        capsule(root, "leftSock",  cr: 0.115, h: 0.28, p: SCNVector3(-0.20, -0.26, 0.02), m: white)
        capsule(root, "rightSock", cr: 0.115, h: 0.28, p: SCNVector3( 0.20, -0.26, 0.02), m: white)

        // Shoes — dark with accent toe
        let shoeGeo = SCNBox(width: 0.22, height: 0.12, length: 0.30, chamferRadius: 0.04)
        shoeGeo.firstMaterial = black
        for xOff: Float in [-0.20, 0.20] {
            let shoe = SCNNode(geometry: shoeGeo)
            shoe.position = SCNVector3(xOff, -0.44, 0.04)
            root.addChildNode(shoe)
        }

        // ── Environment glow ────────────────────────────────────────────────
        let glowGeo = SCNSphere(radius: 1.55)
        glowGeo.firstMaterial = mat(
            UIColor(red: 0.50, green: 0.58, blue: 1.0, alpha: 0.14),
            rough: 1.0)
        glowGeo.firstMaterial?.isDoubleSided = true
        let glowNode = SCNNode(geometry: glowGeo)
        glowNode.name = "environmentGlow"
        glowNode.position = SCNVector3(0, 1.60, -1.0)
        glowNode.scale = SCNVector3(1.08, 1.22, 0.08)
        root.addChildNode(glowNode)

        // ── Animations ──────────────────────────────────────────────────────
        // Breathing — subtle whole-body scale
        root.runAction(.repeatForever(.sequence([
            .scale(to: 1.018, duration: 2.0),
            .scale(to: 1.000, duration: 2.0)
        ])), forKey: "breathing")

        // Head gentle sway
        head.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z:  0.030, duration: 1.8),
            .rotateTo(x: 0, y: 0, z: -0.030, duration: 1.8)
        ])), forKey: "headIdle")

        // Arm sway
        leftArm.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: -0.30, duration: 1.4),
            .rotateTo(x: 0, y: 0, z: -0.46, duration: 1.4)
        ])), forKey: "armSwayL")
        rightArm.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: 0.46, duration: 1.4),
            .rotateTo(x: 0, y: 0, z: 0.30, duration: 1.4)
        ])), forKey: "armSwayR")

        // Skirt subtle float
        skirt.runAction(.repeatForever(.sequence([
            .moveBy(x: 0, y: 0.008, z: 0, duration: 1.8),
            .moveBy(x: 0, y: -0.008, z: 0, duration: 1.8)
        ])), forKey: "skirtFloat")

        return scene
    }

    // MARK: - Helpers

    @discardableResult
    private func sphere(_ parent: SCNNode, _ name: String,
                        r: CGFloat, p: SCNVector3,
                        m: SCNMaterial, s: SCNVector3? = nil,
                        seg: Int = 48) -> SCNNode {
        let geo = SCNSphere(radius: r)
        geo.segmentCount = seg
        geo.firstMaterial = m
        let n = SCNNode(geometry: geo)
        n.name = name
        n.position = p
        if let s { n.scale = s }
        parent.addChildNode(n)
        return n
    }

    @discardableResult
    private func capsule(_ parent: SCNNode, _ name: String,
                         cr: CGFloat, h: CGFloat,
                         p: SCNVector3, m: SCNMaterial) -> SCNNode {
        let geo = SCNCapsule(capRadius: cr, height: h)
        geo.radialSegmentCount = 32
        geo.firstMaterial = m
        let n = SCNNode(geometry: geo)
        n.name = name
        n.position = p
        parent.addChildNode(n)
        return n
    }

    private func mat(_ color: UIColor,
                     rough: CGFloat = 0.48,
                     metal: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = rough
        m.metalness.contents = metal
        m.lightingModel = .physicallyBased
        return m
    }

    private func addLight(to scene: SCNScene,
                          type: SCNLight.LightType,
                          intensity: CGFloat,
                          color: UIColor,
                          position: SCNVector3) {
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