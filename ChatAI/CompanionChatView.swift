import SwiftUI
import RealityKit
import UIKit

/// First MVP shell for the 3D companion experience.
/// The primitive avatar is a temporary stand-in until a rigged USDZ character is added.
struct CompanionChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceManager = VoiceManager()
    @State private var emotion: CompanionEmotion = .idle
    @State private var showConversation = true
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
                    CompanionRealityView(emotion: emotion, isNight: isNight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            emotion = .surprised
                            touchMessage = "Ơ, anh làm em giật mình đó!"
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
        .onChange(of: viewModel.messages.count) { _ in
            guard let last = viewModel.messages.last, last.role == .assistant else { return }
            emotion = .happy
        }
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
            HStack(spacing: 18) {
                touchButton("Đầu", icon: "hand.tap", emotion: .surprised, message: "Ơ hay, lại định trêu gì em đấy?")
                touchButton("Má", icon: "heart", emotion: .shy, message: "Ơ... anh đừng chọc em nữa mà!")
                touchButton("Vui", icon: "face.smiling", emotion: .happy, message: nil)
            }

            HStack(spacing: 14) {
                Button {
                    let groqKey = KeychainHelper.read(forKey: AIProviderKind.groq.keychainKey) ?? ""
                    voiceManager.startListening(
                        groqAPIKey: groqKey,
                        onPartialResult: { _ in },
                        onFinish: { text in
                            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            viewModel.inputText = text
                            viewModel.send()
                        }
                    )
                } label: {
                    Image(systemName: voiceManager.isListening ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                        .background(voiceManager.isListening ? .red.opacity(0.8) : .white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(voiceManager.isListening ? "Dừng ghi âm và gửi" : "Bắt đầu nói")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showConversation = true
                    }
                } label: {
                    Label("Tiếp tục chat", systemImage: "message.fill")
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

    private func touchButton(_ title: String, icon: String, emotion nextEmotion: CompanionEmotion, message: String?) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                emotion = nextEmotion
                touchMessage = message
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.11), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
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

/// Lightweight RealityKit stand-in. Replace this procedural avatar with a rigged USDZ model
/// before claiming full facial expressions, touch hit-testing, or real lip-sync.
private struct CompanionRealityView: UIViewRepresentable {
    let emotion: CompanionEmotion
    let isNight: Bool

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

        let avatar = makePlaceholderAvatar()
        let avatarAnchor = AnchorEntity(world: [0, -0.15, 0])
        avatarAnchor.addChild(avatar)
        view.scene.addAnchor(avatarAnchor)
        context.coordinator.avatarAnchor = avatarAnchor
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        view.environment.background = .color(isNight ? UIColor(red: 0.045, green: 0.07, blue: 0.18, alpha: 1) : UIColor(red: 0.27, green: 0.32, blue: 0.43, alpha: 1))
        if let avatar = context.coordinator.avatarAnchor?.children.first {
            switch emotion {
            case .idle:
                avatar.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
            case .happy:
                avatar.transform.rotation = simd_quatf(angle: 0.08, axis: [0, 1, 0])
            case .thinking:
                avatar.transform.rotation = simd_quatf(angle: -0.18, axis: [0, 1, 0])
            case .shy:
                avatar.transform.rotation = simd_quatf(angle: 0.2, axis: [0, 1, 0])
            case .surprised:
                avatar.transform.rotation = simd_quatf(angle: -0.08, axis: [1, 0, 0])
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var avatarAnchor: AnchorEntity?
    }

    private func makePlaceholderAvatar() -> Entity {
        let root = Entity()
        let skin = SimpleMaterial(color: UIColor(red: 0.96, green: 0.72, blue: 0.66, alpha: 1), roughness: 0.42, isMetallic: false)
        let hair = SimpleMaterial(color: UIColor(red: 0.16, green: 0.10, blue: 0.20, alpha: 1), roughness: 0.32, isMetallic: false)
        let outfit = SimpleMaterial(color: UIColor(red: 0.18, green: 0.22, blue: 0.34, alpha: 1), roughness: 0.5, isMetallic: false)
        let eye = SimpleMaterial(color: UIColor(red: 0.12, green: 0.07, blue: 0.16, alpha: 1), roughness: 0.25, isMetallic: false)

        let torso = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.42, 0.78, 0.28)), materials: [outfit])
        torso.position = [0, -0.48, 0]
        root.addChild(torso)

        let head = ModelEntity(mesh: .generateSphere(radius: 0.34), materials: [skin])
        head.position = [0, 0.16, 0.02]
        root.addChild(head)

        let hairCap = ModelEntity(mesh: .generateSphere(radius: 0.355), materials: [hair])
        hairCap.position = [0, 0.27, -0.055]
        hairCap.scale = [1.0, 0.72, 0.9]
        root.addChild(hairCap)

        for x: Float in [-0.13, 0.13] {
            let eyeEntity = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [eye])
            eyeEntity.position = [x, 0.17, 0.335]
            eyeEntity.scale = [1, 1.25, 0.35]
            root.addChild(eyeEntity)
        }

        let fringe = ModelEntity(mesh: .generateBox(size: [0.45, 0.12, 0.08]), materials: [hair])
        fringe.position = [0, 0.39, 0.29]
        fringe.orientation = simd_quatf(angle: -0.18, axis: [0, 0, 1])
        root.addChild(fringe)

        return root
    }
}
