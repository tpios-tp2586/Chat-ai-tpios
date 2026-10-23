import SwiftUI
import RealityKit
import UIKit

/// 3D companion screen. Loads the bundled rigged CompanionChibi.usdz when available.
/// The procedural avatar remains only as a temporary fallback until the real asset is bundled.
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
                        CompanionRealityView(emotion: emotion, isNight: isNight, isSpeaking: liveManager.aiSpeaking)
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

/// RealityKit host for the rigged anime chibi asset. A bundled CompanionChibi.usdz takes priority;
/// the procedural avatar below is only a fallback and does not provide real facial animation.
private struct CompanionRealityView: UIViewRepresentable {
    let emotion: CompanionEmotion
    let isNight: Bool
    let isSpeaking: Bool

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(isNight ? UIColor(red: 0.045, green: 0.07, blue: 0.18, alpha: 1) : UIColor(red: 0.27, green: 0.32, blue: 0.43, alpha: 1))

        let camera = PerspectiveCamera()
        camera.position = [0, 0.1, 2.7]
        camera.look(at: [0, 0.1, 0], from: camera.position, relativeTo: nil)
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(camera)
        view.scene.addAnchor(cameraAnchor)

        let lightAnchor = AnchorEntity(world: .zero)
        let light = DirectionalLight()
        light.light.intensity = isNight ? 900 : 1500
        light.orientation = simd_quatf(angle: -.pi / 5, axis: [1, 0, 0])
        lightAnchor.addChild(light)
        view.scene.addAnchor(lightAnchor)

        // Prefer the real, rigged anime chibi asset. Add CompanionChibi.usdz to the app target's
        // Copy Bundle Resources; keep the fallback so the screen remains usable during integration.
        let avatar = (try? Entity.load(named: "CompanionChibi")) ?? makePlaceholderAvatar()
        avatar.name = "companionAvatarRoot"
        let avatarAnchor = AnchorEntity(world: [0, -0.15, 0])
        avatarAnchor.addChild(avatar)
        view.scene.addAnchor(avatarAnchor)
        context.coordinator.avatarAnchor = avatarAnchor
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        view.environment.background = .color(isNight ? UIColor(red: 0.045, green: 0.07, blue: 0.18, alpha: 1) : UIColor(red: 0.27, green: 0.32, blue: 0.43, alpha: 1))
        if let avatar = context.coordinator.avatarAnchor?.children.first {
            let yaw: Float
            switch emotion {
            case .idle: yaw = 0
            case .happy: yaw = 0.08
            case .thinking: yaw = -0.18
            case .shy: yaw = 0.2
            case .surprised: yaw = -0.08
            }
            avatar.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            let leftArm = avatar.findEntity(named: "leftArmPivot")
            let rightArm = avatar.findEntity(named: "rightArmPivot")
            let leftLeg = avatar.findEntity(named: "leftLegPivot")
            let rightLeg = avatar.findEntity(named: "rightLegPivot")
            let armSwing: Float = isSpeaking ? 0.18 : 0.035
            leftArm?.transform.rotation = simd_quatf(angle: emotion == .shy ? -0.38 : armSwing, axis: [0, 0, 1])
            rightArm?.transform.rotation = simd_quatf(angle: emotion == .happy ? -0.42 : -armSwing, axis: [0, 0, 1])
            leftLeg?.transform.rotation = simd_quatf(angle: emotion == .surprised ? -0.12 : 0, axis: [1, 0, 0])
            rightLeg?.transform.rotation = simd_quatf(angle: emotion == .surprised ? 0.12 : 0, axis: [1, 0, 0])
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var avatarAnchor: AnchorEntity?
    }

    private func makePlaceholderAvatar() -> Entity {
        let root = Entity()
        let skin = SimpleMaterial(color: UIColor(red: 0.91, green: 0.70, blue: 0.61, alpha: 1), roughness: 0.42, isMetallic: false)
        let hair = SimpleMaterial(color: UIColor(red: 0.12, green: 0.075, blue: 0.07, alpha: 1), roughness: 0.28, isMetallic: false)
        let outfit = SimpleMaterial(color: UIColor(red: 0.20, green: 0.31, blue: 0.48, alpha: 1), roughness: 0.48, isMetallic: false)
        let white = SimpleMaterial(color: .white, roughness: 0.2, isMetallic: false)
        let iris = SimpleMaterial(color: UIColor(red: 0.22, green: 0.12, blue: 0.08, alpha: 1), roughness: 0.2, isMetallic: false)
        let dark = SimpleMaterial(color: UIColor(red: 0.18, green: 0.09, blue: 0.10, alpha: 1), roughness: 0.4, isMetallic: false)
        let blush = SimpleMaterial(color: UIColor(red: 0.88, green: 0.36, blue: 0.39, alpha: 0.45), roughness: 0.6, isMetallic: false)
        func part(_ radius: Float, _ material: RealityKit.Material, _ position: SIMD3<Float>, _ scale: SIMD3<Float>) -> ModelEntity {
            let e = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
            e.position = position
            e.scale = scale
            return e
        }

        // Full-body silhouette, centered for the portrait camera.
        let body = Entity()
        body.name = "body"
        body.position = [0, -0.52, 0]
        root.addChild(body)
        body.addChild(part(0.22, outfit, [0, 0.02, 0], [1.0, 1.35, 0.72])) // torso
        body.addChild(part(0.19, outfit, [0, -0.28, 0], [1.15, 0.78, 0.8])) // skirt/hips
        body.addChild(part(0.075, skin, [0, 0.29, 0.01], [0.85, 1.15, 0.85])) // neck

        // Legs have separate thigh/shin groups, with pivots for animation.
        for (x, prefix): (Float, String) in [(-0.105, "left"), (0.105, "right")] {
            let legPivot = Entity()
            legPivot.name = "\(prefix)LegPivot"
            legPivot.position = [x, -0.30, 0]
            body.addChild(legPivot)
            legPivot.addChild(part(0.105, skin, [0, -0.12, 0], [0.72, 1.5, 0.78]))
            let shin = Entity()
            shin.position = [0, -0.27, 0]
            legPivot.addChild(shin)
            shin.addChild(part(0.078, skin, [0, -0.10, 0], [0.72, 1.65, 0.78]))
            shin.addChild(part(0.095, outfit, [0, -0.27, 0.055], [1.0, 0.52, 1.35]))
            shin.addChild(part(0.105, dark, [0, -0.34, 0.07], [1.0, 0.28, 1.55]))
        }

        // Arms are articulated at the shoulder and have forearms and hands.
        for (x, prefix): (Float, String) in [(-0.28, "left"), (0.28, "right")] {
            let arm = Entity()
            arm.name = "\(prefix)ArmPivot"
            arm.position = [x, 0.16, 0]
            body.addChild(arm)
            arm.addChild(part(0.095, outfit, [0, -0.12, 0], [0.82, 1.55, 0.82]))
            let forearm = Entity()
            forearm.position = [0, -0.23, 0.015]
            forearm.orientation = simd_quatf(angle: prefix == "left" ? -0.08 : 0.08, axis: [0, 0, 1])
            arm.addChild(forearm)
            forearm.addChild(part(0.072, skin, [0, -0.11, 0.01], [0.78, 1.6, 0.78]))
            forearm.addChild(part(0.065, skin, [0, -0.23, 0.045], [0.92, 0.92, 0.82]))
        }

        // Head, ears, layered fringe, eyes, nose and cheeks.
        let head = Entity()
        head.name = "head"
        head.position = [0, 0.22, 0.02]
        root.addChild(head)
        head.addChild(part(0.315, skin, [0, 0, 0], [0.88, 1.12, 0.82]))
        for x: Float in [-0.275, 0.275] {
            head.addChild(part(0.075, skin, [x, -0.01, 0], [0.72, 1.0, 0.7]))
        }
        head.addChild(part(0.335, hair, [0, 0.12, -0.06], [0.94, 0.88, 0.88]))
        head.addChild(part(0.30, skin, [0, -0.07, 0.07], [0.88, 0.91, 0.83]))
        for x: Float in [-0.18, 0, 0.18] {
            let bang = part(0.15, hair, [x, 0.205, 0.20], [0.82, 0.62, 0.42])
            bang.orientation = simd_quatf(angle: x * 0.8, axis: [0, 0, 1])
            head.addChild(bang)
        }
        for x: Float in [-0.27, 0.27] {
            head.addChild(part(0.105, hair, [x, -0.10, 0.12], [0.72, 1.55, 0.55]))
        }
        for x: Float in [-0.12, 0.12] {
            head.addChild(part(0.057, white, [x, 0.00, 0.279], [0.82, 1.2, 0.42]))
            head.addChild(part(0.033, iris, [x, -0.005, 0.303], [0.78, 1.25, 0.35]))
            head.addChild(part(0.012, white, [x - 0.009, 0.013, 0.315], [1, 1, 0.5]))
        }
        head.addChild(part(0.025, skin, [0, -0.095, 0.305], [0.8, 0.8, 0.55]))
        head.addChild(part(0.043, dark, [0, -0.165, 0.294], [1.25, 0.42, 0.35]))
        for x: Float in [-0.19, 0.19] {
            head.addChild(part(0.048, blush, [x, -0.105, 0.274], [1.2, 0.55, 0.25]))
        }
        return root
    }
}
