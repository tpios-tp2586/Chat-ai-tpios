import SwiftUI

/// Companion screen with a head-only kawaii robot face.
/// The visual target follows the approved concept: pearl-white shell, pastel-pink rim,
/// black glossy visor, large cyan glass eyes, pink cheeks, antennae, ear modules and fins.
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
    @State private var isNight = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isNight
                    ? [Color(red: 0.015, green: 0.025, blue: 0.075), Color(red: 0.12, green: 0.07, blue: 0.18)]
                    : [Color(red: 0.035, green: 0.05, blue: 0.10), Color(red: 0.17, green: 0.08, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        RobotHeadView(emotion: emotion, isSpeaking: liveManager.aiSpeaking)
                            .frame(width: min(proxy.size.width - 24, 390), height: min(proxy.size.height * 0.70, 430))
                            .contentShape(Rectangle())
                            .onTapGesture { emotion = .happy }

                        Spacer(minLength: 6)
                        statusPanel
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                controls
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: liveManager.lines.count) { _ in
            guard let line = liveManager.lines.last else { return }
            touchMessage = line.text
            emotion = line.role == .assistant ? .happy : .thinking
        }
        .onChange(of: liveManager.errorText) { message in
            if let message, !message.isEmpty { touchMessage = message }
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            withAnimation(.easeInOut(duration: 0.16)) {
                emotion = speaking ? .speaking : (emotion == .speaking ? .idle : emotion)
            }
        }
        .onChange(of: liveManager.state) { state in
            guard !liveManager.aiSpeaking else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                switch state {
                case .idle: emotion = .idle
                case .connecting: emotion = .thinking
                case .live: emotion = .listening
                }
            }
        }
        .onDisappear { liveManager.end() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ChatAI Companion").font(.headline)
                Text(viewModel.selectedProvider.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button { isNight.toggle() } label: {
                Image(systemName: isNight ? "moon.stars.fill" : "sun.max.fill")
                    .font(.title3)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var statusPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Label(statusText, systemImage: statusSymbol)
                    .font(.caption.weight(.semibold))
                Spacer()
            }

            if showConversation {
                if let touchMessage {
                    Text(touchMessage)
                        .font(.subheadline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let reply = viewModel.messages.last(where: { $0.role == .assistant }) {
                    Text(reply.content)
                        .font(.subheadline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Chào anh! Mình trò chuyện nhé.")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                if liveManager.state == .idle { startLive() } else { liveManager.end() }
            } label: {
                Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill")
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.14), in: Circle())
            }

            Button {
                showConversation = true
                if liveManager.state == .idle { startLive() }
            } label: {
                Label(
                    liveManager.state == .live
                        ? (liveManager.aiSpeaking ? "AI đang nói..." : "Đang nghe anh")
                        : (liveManager.state == .connecting ? "Đang kết nối..." : "Tiếp tục chat"),
                    systemImage: "waveform"
                )
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 52, height: 52)
                    .background(.red.opacity(0.85), in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.24))
    }

    private func startLive() {
        liveManager.start(model: liveModel, voice: liveVoice, persona: livePersona, bargeIn: liveBargeIn)
    }

    private var statusText: String {
        switch emotion {
        case .idle: "Đang ở đây với anh"
        case .listening: "Em đang nghe anh"
        case .thinking: "Đang suy nghĩ"
        case .speaking: "Em đang nói"
        case .happy: "Em đang vui"
        case .surprised: "Bất ngờ quá!"
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

private struct RobotHeadView: View {
    let emotion: CompanionEmotion
    let isSpeaking: Bool
    @State private var floatUp = false
    @State private var gaze: CGFloat = 0
    @State private var glow = false
    @State private var blink = false
    @State private var mouthPulse = false

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 390, geo.size.height / 430)
            let eyeH = (blink ? 5 : eyeHeight) * scale
            let eyeW = eyeWidth * scale

            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.10))
                    .frame(width: 330 * scale, height: 330 * scale)
                    .blur(radius: 46)

                // Transparent butterfly-like side fins sit behind the ear modules.
                RobotFin(side: -1, scale: scale).position(x: 47 * scale, y: 278 * scale)
                RobotFin(side: 1, scale: scale).position(x: 343 * scale, y: 278 * scale)

                // Pearl shell: three layers create the rounded concept-art silhouette.
                RoundedRectangle(cornerRadius: 103 * scale, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(red: 0.99, green: 0.96, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 330 * scale, height: 286 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 103 * scale, style: .continuous)
                            .stroke(Color(red: 1, green: 0.66, blue: 0.84), lineWidth: 10 * scale)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 94 * scale, style: .continuous)
                            .stroke(Color.white.opacity(0.95), lineWidth: 3 * scale)
                            .padding(8 * scale)
                    )
                    .shadow(color: Color(red: 1, green: 0.38, blue: 0.68).opacity(0.24), radius: 18 * scale, y: 10 * scale)
                    .position(x: 195 * scale, y: 235 * scale)

                // Subtle shell seam lines.
                Capsule().fill(Color(red: 0.43, green: 0.82, blue: 1).opacity(0.65))
                    .frame(width: 4 * scale, height: 34 * scale)
                    .rotationEffect(.degrees(20))
                    .position(x: 104 * scale, y: 91 * scale)
                Capsule().fill(Color(red: 0.43, green: 0.82, blue: 1).opacity(0.65))
                    .frame(width: 4 * scale, height: 34 * scale)
                    .rotationEffect(.degrees(-20))
                    .position(x: 286 * scale, y: 91 * scale)

                // Glossy black OLED visor.
                RoundedRectangle(cornerRadius: 72 * scale, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.015, green: 0.02, blue: 0.035), Color(red: 0.005, green: 0.01, blue: 0.018), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 286 * scale, height: 190 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 72 * scale, style: .continuous)
                            .stroke(Color(red: 1, green: 0.67, blue: 0.84), lineWidth: 5 * scale)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 68 * scale, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 2 * scale)
                            .padding(6 * scale)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 10 * scale, y: 6 * scale)
                    .position(x: 195 * scale, y: 239 * scale)

                // Visor glass reflections.
                Capsule().fill(.white.opacity(0.22))
                    .frame(width: 64 * scale, height: 12 * scale)
                    .rotationEffect(.degrees(-28))
                    .position(x: 118 * scale, y: 178 * scale)
                Capsule().fill(.white.opacity(0.10))
                    .frame(width: 30 * scale, height: 7 * scale)
                    .rotationEffect(.degrees(28))
                    .position(x: 271 * scale, y: 190 * scale)

                // Large glassy cyan eyes: ring + iris + dark pupil + two reflections.
                RobotEye(height: eyeH, width: eyeW, pupilOffset: pupilOffset + gaze, glowPulse: glow)
                    .position(x: 139 * scale, y: 232 * scale)
                RobotEye(height: eyeH, width: eyeW, pupilOffset: pupilOffset + gaze, glowPulse: glow)
                    .position(x: 251 * scale, y: 232 * scale)

                // Small expressive brow strokes are part of the approved face language.
                RobotBrow(emotion: emotion, side: -1, scale: scale).position(x: 140 * scale, y: 194 * scale)
                RobotBrow(emotion: emotion, side: 1, scale: scale).position(x: 250 * scale, y: 194 * scale)

                // Pink cheeks.
                Capsule().fill(Color(red: 1, green: 0.39, blue: 0.68).opacity(0.92))
                    .frame(width: 31 * scale, height: 10 * scale)
                    .rotationEffect(.degrees(-5))
                    .shadow(color: .pink.opacity(0.35), radius: 4 * scale)
                    .position(x: 94 * scale, y: 292 * scale)
                Capsule().fill(Color(red: 1, green: 0.39, blue: 0.68).opacity(0.92))
                    .frame(width: 31 * scale, height: 10 * scale)
                    .rotationEffect(.degrees(5))
                    .shadow(color: .pink.opacity(0.35), radius: 4 * scale)
                    .position(x: 296 * scale, y: 292 * scale)

                RobotMouth(emotion: emotion, isSpeaking: isSpeaking, scale: scale, mouthPulse: mouthPulse)
                    .position(x: 195 * scale, y: 292 * scale)

                // Antennae with pink luminous tips.
                Capsule().fill(Color(red: 0.42, green: 0.83, blue: 1))
                    .frame(width: 6 * scale, height: 48 * scale)
                    .rotationEffect(.degrees(-12))
                    .position(x: 132 * scale, y: 57 * scale)
                Capsule().fill(Color(red: 0.42, green: 0.83, blue: 1))
                    .frame(width: 6 * scale, height: 48 * scale)
                    .rotationEffect(.degrees(12))
                    .position(x: 258 * scale, y: 57 * scale)
                RobotAntennaTip(scale: scale).position(x: 126 * scale, y: 31 * scale)
                RobotAntennaTip(scale: scale).position(x: 264 * scale, y: 31 * scale)

                RobotEar(side: -1, scale: scale).position(x: 35 * scale, y: 222 * scale)
                RobotEar(side: 1, scale: scale).position(x: 355 * scale, y: 222 * scale)
            }
            .frame(width: 390 * scale, height: 430 * scale)
            .scaleEffect(glow ? 1.004 : 0.998)
            .offset(y: floatUp ? -3 * scale : 3 * scale)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { floatUp = true }
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { gaze = 2.5 }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
                Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.6...4.8) * 1_000_000_000))
                        withAnimation(.easeInOut(duration: 0.08)) { blink = true }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) { blink = false }
                    }
                }
            }
            .onChange(of: isSpeaking) { speaking in
                guard speaking else { mouthPulse = false; return }
                withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) { mouthPulse = true }
            }
        }
        .accessibilityLabel("ChatAI robot companion")
    }

    private var eyeHeight: CGFloat {
        switch emotion {
        case .happy: 55
        case .sleepy: 31
        case .surprised: 73
        case .angry: 45
        default: 66
        }
    }

    private var eyeWidth: CGFloat {
        switch emotion {
        case .surprised: 57
        case .sleepy: 59
        default: 53
        }
    }

    private var pupilOffset: CGFloat {
        switch emotion {
        case .thinking: -7
        case .confused: -5
        default: 0
        }
    }
}

private struct RobotEye: View {
    let height: CGFloat
    let width: CGFloat
    let pupilOffset: CGFloat
    let glowPulse: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.cyan.opacity(glowPulse ? 0.34 : 0.18))
                .frame(width: width + 25, height: height + 25)
                .blur(radius: glowPulse ? 10 : 6)

            Ellipse()
                .fill(LinearGradient(colors: [Color(red: 0.82, green: 1, blue: 1), Color(red: 0.16, green: 0.96, blue: 1), Color(red: 0, green: 0.55, blue: 0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: width, height: height)
                .overlay(Ellipse().stroke(Color(red: 0.55, green: 1, blue: 1), lineWidth: 2))
                .shadow(color: .cyan.opacity(glowPulse ? 0.95 : 0.60), radius: glowPulse ? 12 : 6)

            Ellipse()
                .fill(LinearGradient(colors: [Color(red: 0.06, green: 0.72, blue: 0.80), Color(red: 0.01, green: 0.28, blue: 0.38)], startPoint: .top, endPoint: .bottom))
                .frame(width: width * 0.70, height: height * 0.78)
                .offset(x: pupilOffset)

            Ellipse()
                .fill(Color(red: 0.002, green: 0.025, blue: 0.035))
                .frame(width: width * 0.39, height: height * 0.58)
                .offset(x: pupilOffset + width * 0.02)

            Circle()
                .fill(.white)
                .frame(width: width * 0.27, height: width * 0.27)
                .shadow(color: .white.opacity(0.65), radius: 2)
                .offset(x: -width * 0.19, y: -height * 0.25)

            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: width * 0.12, height: width * 0.12)
                .offset(x: width * 0.17, y: height * 0.20)

            Capsule()
                .fill(.white.opacity(0.46))
                .frame(width: width * 0.24, height: height * 0.07)
                .rotationEffect(.degrees(-30))
                .offset(x: -width * 0.18, y: -height * 0.39)
        }
    }
}

private struct RobotBrow: View {
    let emotion: CompanionEmotion
    let side: CGFloat
    let scale: CGFloat

    var body: some View {
        Capsule()
            .fill(Color(red: 0.35, green: 0.92, blue: 1).opacity(emotion == .angry ? 1 : 0.72))
            .frame(width: 42 * scale, height: 5 * scale)
            .rotationEffect(.degrees(angle))
            .shadow(color: .cyan.opacity(0.65), radius: 4 * scale)
    }

    private var angle: Double {
        switch emotion {
        case .angry: return side < 0 ? 24 : -24
        case .sad: return side < 0 ? -15 : 15
        case .confused: return side < 0 ? -10 : 15
        case .thinking: return side < 0 ? -8 : 8
        default: return side < 0 ? -5 : 5
        }
    }
}

private struct RobotMouth: View {
    let emotion: CompanionEmotion
    let isSpeaking: Bool
    let scale: CGFloat
    let mouthPulse: Bool

    var body: some View {
        if emotion == .happy || emotion == .shy {
            HStack(spacing: -2 * scale) {
                Capsule().fill(Color(red: 1, green: 0.48, blue: 0.73)).frame(width: 15 * scale, height: 5 * scale).rotationEffect(.degrees(24))
                Capsule().fill(Color(red: 1, green: 0.48, blue: 0.73)).frame(width: 15 * scale, height: 5 * scale).rotationEffect(.degrees(-24))
            }
        } else if emotion == .sad {
            HStack(spacing: -2 * scale) {
                Capsule().fill(Color(red: 1, green: 0.48, blue: 0.73)).frame(width: 15 * scale, height: 5 * scale).rotationEffect(.degrees(-24))
                Capsule().fill(Color(red: 1, green: 0.48, blue: 0.73)).frame(width: 15 * scale, height: 5 * scale).rotationEffect(.degrees(24))
            }
        } else if isSpeaking || emotion == .surprised {
            Capsule()
                .fill(Color.black)
                .frame(width: (isSpeaking ? (mouthPulse ? 39 : 29) : 25) * scale, height: (isSpeaking ? (mouthPulse ? 24 : 11) : 28) * scale)
                .overlay(Capsule().stroke(Color(red: 1, green: 0.44, blue: 0.72), lineWidth: 3 * scale))
                .shadow(color: .pink.opacity(isSpeaking ? 0.75 : 0.30), radius: isSpeaking ? 7 * scale : 3 * scale)
        } else {
            HStack(spacing: -2 * scale) {
                Capsule().fill(Color(red: 1, green: 0.52, blue: 0.74)).frame(width: 14 * scale, height: 5 * scale).rotationEffect(.degrees(25))
                Capsule().fill(Color(red: 1, green: 0.52, blue: 0.74)).frame(width: 14 * scale, height: 5 * scale).rotationEffect(.degrees(-25))
            }
        }
    }
}

private struct RobotEar: View {
    let side: CGFloat
    let scale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.white, Color(red: 0.86, green: 0.95, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 82 * scale, height: 82 * scale)
                .overlay(Circle().stroke(Color(red: 1, green: 0.58, blue: 0.80), lineWidth: 7 * scale))
                .shadow(color: .pink.opacity(0.20), radius: 7 * scale)

            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.88, blue: 1), Color(red: 0.26, green: 0.66, blue: 0.95)], startPoint: .top, endPoint: .bottom))
                .frame(width: 54 * scale, height: 54 * scale)
                .overlay(Circle().stroke(Color(red: 1, green: 0.76, blue: 0.89), lineWidth: 4 * scale))

            Image(systemName: "sparkle")
                .font(.system(size: 20 * scale, weight: .bold))
                .foregroundStyle(.white)
        }
        .rotationEffect(.degrees(side < 0 ? -8 : 8))
    }
}

private struct RobotFin: View {
    let side: CGFloat
    let scale: CGFloat

    var body: some View {
        ZStack {
            RobotFinShape()
                .fill(LinearGradient(colors: [Color.white.opacity(0.96), Color(red: 0.56, green: 0.86, blue: 1).opacity(0.80)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92 * scale, height: 118 * scale)
                .overlay(RobotFinShape().stroke(Color(red: 1, green: 0.70, blue: 0.87), lineWidth: 4 * scale))

            VStack(spacing: 13 * scale) {
                Capsule().fill(.white.opacity(0.80)).frame(width: 55 * scale, height: 2 * scale)
                Capsule().fill(.white.opacity(0.80)).frame(width: 62 * scale, height: 2 * scale)
                Capsule().fill(.white.opacity(0.80)).frame(width: 48 * scale, height: 2 * scale)
            }
            .rotationEffect(.degrees(side < 0 ? -14 : 14))
        }
        .rotationEffect(.degrees(side < 0 ? -10 : 10))
    }
}

private struct RobotFinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.04))
        p.addCurve(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.40), control1: CGPoint(x: rect.width * 0.96, y: rect.height * 0.00), control2: CGPoint(x: rect.width * 1.02, y: rect.height * 0.24))
        p.addCurve(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.96), control1: CGPoint(x: rect.width * 0.92, y: rect.height * 0.82), control2: CGPoint(x: rect.width * 0.70, y: rect.height * 1.03))
        p.addCurve(to: CGPoint(x: rect.width * 0.06, y: rect.height * 0.48), control1: CGPoint(x: rect.width * 0.13, y: rect.height * 0.91), control2: CGPoint(x: rect.width * -0.03, y: rect.height * 0.62))
        p.addCurve(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.04), control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.12), control2: CGPoint(x: rect.width * 0.35, y: rect.height * 0.00))
        p.closeSubpath()
        return p
    }
}

private struct RobotAntennaTip: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.pink.opacity(0.25)).frame(width: 38 * scale, height: 38 * scale).blur(radius: 6 * scale)
            Circle()
                .fill(LinearGradient(colors: [.white, Color(red: 1, green: 0.54, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28 * scale, height: 28 * scale)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2 * scale))
            Circle().fill(.white.opacity(0.75)).frame(width: 8 * scale, height: 8 * scale).offset(x: -5 * scale, y: -5 * scale)
        }
    }
}
