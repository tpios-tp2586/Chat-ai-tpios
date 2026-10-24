import SwiftUI

/// Companion screen with a head-only kawaii robot face.
/// The visual target intentionally follows the approved concept: white/pink shell,
/// large black rounded visor, cyan expressive eyes, small mouth, antennae and ears/fins.
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
                        RobotHeadView(
                            emotion: emotion,
                            isSpeaking: liveManager.aiSpeaking
                        )
                        .frame(
                            width: min(proxy.size.width - 24, 390),
                            height: min(proxy.size.height * 0.70, 430)
                        )
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
                .background(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
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
        liveManager.start(
            model: liveModel,
            voice: liveVoice,
            persona: livePersona,
            bargeIn: liveBargeIn
        )
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
    @State private var isFloating = false
    @State private var gazeShift: CGFloat = 0
    @State private var glowPulse = false
    @State private var blink = false
    @State private var mouthPulse = false

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 390, geo.size.height / 430)
            let eyeHeight = (blink ? 5 : eyeHeightForEmotion) * scale
            let eyeWidth = eyeWidthForEmotion * scale

            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 320 * scale, height: 320 * scale)
                    .blur(radius: 42)

                RobotEar(side: -1, scale: scale)
                    .position(x: 28 * scale, y: 220 * scale)
                RobotEar(side: 1, scale: scale)
                    .position(x: 362 * scale, y: 220 * scale)

                RoundedRectangle(cornerRadius: 82 * scale, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(red: 0.98, green: 0.95, blue: 0.98)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 334 * scale, height: 286 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 82 * scale, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, Color(red: 1, green: 0.54, blue: 0.76), Color(red: 0.96, green: 0.68, blue: 0.84)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 11 * scale
                            )
                    )
                    .shadow(color: .pink.opacity(0.18), radius: 16 * scale, y: 10 * scale)
                    .position(x: 195 * scale, y: 235 * scale)

                RoundedRectangle(cornerRadius: 67 * scale, style: .continuous)
                    .stroke(Color(red: 1, green: 0.72, blue: 0.86).opacity(0.72), lineWidth: 5 * scale)
                    .frame(width: 312 * scale, height: 264 * scale)
                    .position(x: 195 * scale, y: 235 * scale)

                RoundedRectangle(cornerRadius: 49 * scale, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.005, green: 0.008, blue: 0.015), Color(red: 0.018, green: 0.035, blue: 0.06), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 282 * scale, height: 182 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 49 * scale, style: .continuous)
                            .stroke(.white.opacity(0.13), lineWidth: 2 * scale)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 9 * scale, y: 6 * scale)
                    .position(x: 195 * scale, y: 238 * scale)

                Capsule()
                    .fill(.white.opacity(0.42))
                    .frame(width: 72 * scale, height: 13 * scale)
                    .rotationEffect(.degrees(-25))
                    .position(x: 124 * scale, y: 178 * scale)

                RobotEye(height: eyeHeight, width: eyeWidth, pupilOffset: pupilOffset + gazeShift, glowPulse: glowPulse)
                    .position(x: 142 * scale, y: 232 * scale)
                RobotEye(height: eyeHeight, width: eyeWidth, pupilOffset: pupilOffset + gazeShift, glowPulse: glowPulse)
                    .position(x: 248 * scale, y: 232 * scale)

                Capsule()
                    .fill(Color(red: 1, green: 0.43, blue: 0.68).opacity(0.90))
                    .frame(width: 31 * scale, height: 10 * scale)
                    .position(x: 103 * scale, y: 291 * scale)
                Capsule()
                    .fill(Color(red: 1, green: 0.43, blue: 0.68).opacity(0.90))
                    .frame(width: 31 * scale, height: 10 * scale)
                    .position(x: 287 * scale, y: 291 * scale)

                RobotMouth(emotion: emotion, isSpeaking: isSpeaking, scale: scale, mouthPulse: mouthPulse)
                    .position(x: 195 * scale, y: 291 * scale)

                Capsule()
                    .fill(Color(red: 0.45, green: 0.83, blue: 1))
                    .frame(width: 7 * scale, height: 54 * scale)
                    .rotationEffect(.degrees(-9))
                    .position(x: 136 * scale, y: 56 * scale)
                Capsule()
                    .fill(Color(red: 0.45, green: 0.83, blue: 1))
                    .frame(width: 7 * scale, height: 54 * scale)
                    .rotationEffect(.degrees(9))
                    .position(x: 254 * scale, y: 56 * scale)

                Circle()
                    .fill(Color(red: 1, green: 0.61, blue: 0.78))
                    .frame(width: 30 * scale, height: 30 * scale)
                    .shadow(color: .pink.opacity(0.5), radius: 8 * scale)
                    .position(x: 132 * scale, y: 29 * scale)
                Circle()
                    .fill(Color(red: 1, green: 0.61, blue: 0.78))
                    .frame(width: 30 * scale, height: 30 * scale)
                    .shadow(color: .pink.opacity(0.5), radius: 8 * scale)
                    .position(x: 258 * scale, y: 29 * scale)

                RobotFin(side: -1, scale: scale).position(x: 47 * scale, y: 293 * scale)
                RobotFin(side: 1, scale: scale).position(x: 343 * scale, y: 293 * scale)
            }
            .frame(width: 390 * scale, height: 430 * scale)
            .scaleEffect(glowPulse ? 1.006 : 0.994)
            .offset(y: isFloating ? -4 * scale : 4 * scale)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    gazeShift = 3.5
                }
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
                Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.4...4.8) * 1_000_000_000))
                        withAnimation(.easeInOut(duration: 0.09)) { blink = true }
                        try? await Task.sleep(nanoseconds: 110_000_000)
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { blink = false }
                    }
                }
            }
            .onChange(of: isSpeaking) { speaking in
                guard speaking else { mouthPulse = false; return }
                withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) {
                    mouthPulse = true
                }
            }
        }
        .accessibilityLabel("ChatAI robot companion")
    }

    private var eyeHeightForEmotion: CGFloat {
        switch emotion {
        case .happy: 46
        case .sleepy: 28
        case .surprised: 72
        case .angry: 43
        default: 62
        }
    }

    private var eyeWidthForEmotion: CGFloat {
        switch emotion {
        case .surprised: 54
        case .sleepy: 56
        default: 48
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
                .fill(Color.cyan.opacity(glowPulse ? 0.38 : 0.18))
                .frame(width: width + (glowPulse ? 28 : 18), height: height + (glowPulse ? 28 : 18))
                .blur(radius: glowPulse ? 11 : 6)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.86, green: 1, blue: 1), .cyan, Color(red: 0.05, green: 0.52, blue: 0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .shadow(color: .cyan.opacity(glowPulse ? 1.0 : 0.55), radius: glowPulse ? 13 : 6)

            Ellipse()
                .fill(Color(red: 0.05, green: 0.45, blue: 0.60))
                .frame(width: width * 0.55, height: height * 0.58)
                .offset(x: pupilOffset)

            Ellipse()
                .fill(Color.black.opacity(0.92))
                .frame(width: width * 0.29, height: height * 0.44)
                .offset(x: pupilOffset)

            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .offset(x: -width * 0.18, y: -height * 0.23)

            Circle()
                .fill(.white.opacity(0.65))
                .frame(width: 6, height: 6)
                .offset(x: width * 0.20, y: height * 0.20)
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
            Capsule()
                .fill(Color(red: 1, green: 0.44, blue: 0.72))
                .frame(width: 31 * scale, height: 9 * scale)
        } else if isSpeaking || emotion == .surprised {
            Capsule()
                .fill(Color.black)
                .frame(width: (isSpeaking ? (mouthPulse ? 37 : 29) : 22) * scale, height: (isSpeaking ? (mouthPulse ? 25 : 12) : 27) * scale)
                .overlay(Capsule().stroke(Color(red: 1, green: 0.44, blue: 0.72), lineWidth: 3 * scale))
                .shadow(color: .pink.opacity(isSpeaking ? 0.75 : 0.25), radius: isSpeaking ? 7 * scale : 2 * scale)
        } else {
            HStack(spacing: -1 * scale) {
                Capsule().fill(Color(red: 1, green: 0.52, blue: 0.74)).frame(width: 13 * scale, height: 5 * scale).rotationEffect(.degrees(25))
                Capsule().fill(Color(red: 1, green: 0.52, blue: 0.74)).frame(width: 13 * scale, height: 5 * scale).rotationEffect(.degrees(-25))
            }
        }
    }
}

private struct RobotEar: View {
    let side: CGFloat
    let scale: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.white, Color(red: 0.88, green: 0.95, blue: 1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 76 * scale, height: 116 * scale)
                .rotationEffect(.degrees(side < 0 ? -17 : 17))
            Capsule()
                .stroke(Color(red: 0.98, green: 0.65, blue: 0.82), lineWidth: 7 * scale)
                .frame(width: 76 * scale, height: 116 * scale)
                .rotationEffect(.degrees(side < 0 ? -17 : 17))
            Capsule()
                .fill(Color(red: 0.43, green: 0.82, blue: 1).opacity(0.8))
                .frame(width: 31 * scale, height: 76 * scale)
                .rotationEffect(.degrees(side < 0 ? -17 : 17))
        }
    }
}

private struct RobotFin: View {
    let side: CGFloat
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 6 * scale) {
            Capsule().fill(Color(red: 1, green: 0.70, blue: 0.84)).frame(width: 50 * scale, height: 20 * scale)
            Capsule().fill(Color(red: 0.55, green: 0.86, blue: 1)).frame(width: 42 * scale, height: 18 * scale)
            Capsule().fill(Color(red: 1, green: 0.78, blue: 0.88)).frame(width: 35 * scale, height: 16 * scale)
        }
        .rotationEffect(.degrees(side < 0 ? -18 : 18))
    }
}
