import SwiftUI
import UIKit

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
                        Companion2DStage(emotion: emotion, isNight: isNight, isSpeaking: liveManager.aiSpeaking)
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


/// Native SwiftUI 2D stage: layered anime-style character with motion and expression changes.
/// It intentionally avoids RealityKit so the companion works without a bundled 3D model.
private struct Companion2DStage: View {
    let emotion: CompanionEmotion
    let isNight: Bool
    let isSpeaking: Bool
    @State private var blink = false
    @State private var float = false
    @State private var sway = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(.white.opacity(isNight ? 0.07 : 0.12))
                    .frame(width: min(geo.size.width * 0.86, 360))
                    .blur(radius: 1)
                    .offset(y: -20)
                Circle()
                    .stroke(.white.opacity(0.14), lineWidth: 1)
                    .frame(width: min(geo.size.width * 0.92, 390))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white.opacity(0.85))
                            .offset(x: -24, y: 28)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.pink.opacity(0.8))
                            .offset(x: 34, y: -52)
                    }
                VStack(spacing: 0) {
                    character
                        .frame(width: min(geo.size.width * 0.78, 300), height: geo.size.height * 0.77)
                        .offset(y: float ? -7 : 5)
                        .rotationEffect(.degrees(sway ? 1.2 : -1.2), anchor: .bottom)
                        .animation(.easeInOut(duration: isSpeaking ? 0.34 : 2.0).repeatForever(autoreverses: true), value: float)
                        .animation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true), value: sway)
                    Text(isSpeaking ? "♪  đang trò chuyện với anh  ♪" : "chạm vào em nhé ♡")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.18), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                        .padding(.top, -4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                float = true
                sway = true
                startBlinking()
            }
        }
    }

    private var character: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Hair silhouette behind the body
                Ellipse()
                    .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.20), Color(red: 0.055, green: 0.045, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w * 0.83, height: h * 0.45)
                    .offset(y: -h * 0.20)
                // Long side locks
                HStack(spacing: w * 0.48) {
                    Capsule().fill(Color(red: 0.09, green: 0.065, blue: 0.13))
                        .frame(width: w * 0.15, height: h * 0.37)
                        .rotationEffect(.degrees(7))
                    Capsule().fill(Color(red: 0.09, green: 0.065, blue: 0.13))
                        .frame(width: w * 0.15, height: h * 0.37)
                        .rotationEffect(.degrees(-7))
                }
                .offset(y: -h * 0.01)
                // Legs and shoes
                HStack(spacing: w * 0.055) {
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: w * 0.055).fill(Color(red: 0.96, green: 0.77, blue: 0.72))
                            .frame(width: w * 0.13, height: h * 0.19)
                        Capsule().fill(Color(red: 0.18, green: 0.14, blue: 0.24))
                            .frame(width: w * 0.18, height: h * 0.055)
                    }
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: w * 0.055).fill(Color(red: 0.96, green: 0.77, blue: 0.72))
                            .frame(width: w * 0.13, height: h * 0.19)
                        Capsule().fill(Color(red: 0.18, green: 0.14, blue: 0.24))
                            .frame(width: w * 0.18, height: h * 0.055)
                    }
                }
                .offset(y: h * 0.345)
                // Dress body and collar
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: w * 0.16)
                        .fill(LinearGradient(colors: [Color(red: 0.49, green: 0.43, blue: 0.78), Color(red: 0.28, green: 0.27, blue: 0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: w * 0.46, height: h * 0.25)
                        .overlay(alignment: .top) {
                            HStack(spacing: 0) {
                                UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 0)
                                    .fill(.white.opacity(0.9)).frame(width: w * 0.10, height: h * 0.075)
                                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 3)
                                    .fill(.white.opacity(0.9)).frame(width: w * 0.10, height: h * 0.075)
                            }
                        }
                    Trapezoid()
                        .fill(LinearGradient(colors: [Color(red: 0.65, green: 0.58, blue: 0.90), Color(red: 0.37, green: 0.32, blue: 0.67)], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.58, height: h * 0.19)
                        .overlay(alignment: .top) {
                            Rectangle().fill(.white.opacity(0.55)).frame(height: 2).padding(.horizontal, 8)
                        }
                }
                .offset(y: h * 0.19)
                // Arms with small cuffs
                HStack(spacing: w * 0.43) {
                    Capsule().fill(Color(red: 0.49, green: 0.43, blue: 0.78))
                        .frame(width: w * 0.12, height: h * 0.22)
                        .rotationEffect(.degrees(emotion == .shy ? 27 : (isSpeaking ? 12 : -17)))
                        .overlay(alignment: .bottom) {
                            Circle().fill(Color(red: 0.96, green: 0.77, blue: 0.72)).frame(width: w * 0.12)
                        }
                    Capsule().fill(Color(red: 0.49, green: 0.43, blue: 0.78))
                        .frame(width: w * 0.12, height: h * 0.22)
                        .rotationEffect(.degrees(emotion == .happy || isSpeaking ? -27 : 17))
                        .overlay(alignment: .bottom) {
                            Circle().fill(Color(red: 0.96, green: 0.77, blue: 0.72)).frame(width: w * 0.12)
                        }
                }
                .offset(y: h * 0.10)
                // Face and hair framing
                Ellipse()
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.80), Color(red: 0.94, green: 0.68, blue: 0.67)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w * 0.62, height: h * 0.34)
                    .overlay {
                        face
                    }
                    .offset(y: -h * 0.18)
                // Fringe, layered locks and hair shine
                ZStack {
                    UnevenRoundedRectangle(topLeadingRadius: w * 0.22, bottomLeadingRadius: w * 0.06, bottomTrailingRadius: w * 0.05, topTrailingRadius: w * 0.22)
                        .fill(Color(red: 0.12, green: 0.075, blue: 0.16))
                        .frame(width: w * 0.68, height: h * 0.18)
                    HStack(spacing: -w * 0.055) {
                        ForEach(0..<5, id: \.self) { i in
                            Ellipse()
                                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.13, blue: 0.26), Color(red: 0.08, green: 0.055, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: w * 0.17, height: h * (i == 2 ? 0.16 : 0.13))
                                .rotationEffect(.degrees(Double(i - 2) * 12))
                        }
                    }
                    Ellipse().fill(.white.opacity(0.12)).frame(width: w * 0.28, height: h * 0.025).blur(radius: 3).offset(x: -w * 0.10, y: -h * 0.06)
                }
                .offset(y: -h * 0.30)
                // Hair bow
                HStack(spacing: -2) {
                    Ellipse().fill(Color.pink.opacity(0.95)).frame(width: w * 0.11, height: h * 0.065).rotationEffect(.degrees(-24))
                    Circle().fill(Color(red: 1, green: 0.83, blue: 0.89)).frame(width: w * 0.035)
                    Ellipse().fill(Color.pink.opacity(0.95)).frame(width: w * 0.11, height: h * 0.065).rotationEffect(.degrees(24))
                }
                .offset(x: w * 0.24, y: -h * 0.355)
                // Floating heart when happy/shy
                if emotion == .happy || emotion == .shy {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.pink.opacity(0.9))
                        .shadow(color: .pink.opacity(0.45), radius: 10)
                        .offset(x: w * 0.39, y: -h * 0.18)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var face: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                HStack(spacing: w * 0.12) {
                    eye
                    eye
                }
                .offset(y: -h * 0.035)
                Ellipse().fill(Color.pink.opacity(0.25))
                    .frame(width: w * 0.15, height: h * 0.055)
                    .offset(x: -w * 0.28, y: h * 0.10)
                Ellipse().fill(Color.pink.opacity(0.25))
                    .frame(width: w * 0.15, height: h * 0.055)
                    .offset(x: w * 0.28, y: h * 0.10)
                if emotion == .surprised {
                    Ellipse().fill(Color(red: 0.48, green: 0.19, blue: 0.26))
                        .frame(width: w * 0.055, height: h * 0.075)
                        .offset(y: h * 0.105)
                } else {
                    Capsule().fill(Color(red: 0.57, green: 0.25, blue: 0.31))
                        .frame(width: w * 0.10, height: h * (isSpeaking ? 0.04 : 0.018))
                        .offset(y: h * 0.11)
                }
                if emotion == .shy {
                    Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(.pink).offset(y: h * 0.19)
                }
            }
        }
    }

    private var eye: some View {
        ZStack {
            Ellipse().fill(Color(red: 0.22, green: 0.12, blue: 0.25))
                .frame(width: 25, height: blink ? 2 : 34)
            if !blink {
                Ellipse().fill(LinearGradient(colors: [Color(red: 0.70, green: 0.49, blue: 0.91), Color(red: 0.31, green: 0.26, blue: 0.63)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 17, height: 25)
                Circle().fill(.white).frame(width: 7).offset(x: -4, y: -7)
                Circle().fill(.white.opacity(0.7)).frame(width: 3).offset(x: 4, y: 5)
            }
        }
        .animation(.easeInOut(duration: 0.10), value: blink)
    }

    private func startBlinking() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.2...4.2)) {
            withAnimation { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation { blink = false }
                startBlinking()
            }
        }
    }
}

private struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.18, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
