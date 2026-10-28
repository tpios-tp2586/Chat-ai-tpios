import UIKit
import SwiftUI

struct CompanionChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveManager = LiveVoiceManager()

    @AppStorage("live_model") private var liveModel = "gemini-3.8-live"
    @AppStorage("live_voice") private var liveVoice = "Zephyr"
    @AppStorage("live_persona") private var livePersona = LivePersona.defaultText
    @AppStorage("live_barge_in") private var liveBargeIn = false
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue
    @AppStorage(ChatAIThemeStore.accentKey) private var customAccentHex = ""

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    @State private var emotion: CompanionEmotion = .idle
    @State private var message: String?
    @State private var nightMode = false
    @State private var showDiagnosticLog = false
    @State private var diagnosticLogs: [String] = ["[INFO] Mở màn hình Chat Voice"]

    var body: some View {
        ZStack {
            ZStack {
                ChatAIThemeBackground(theme: activeTheme)
                if nightMode { Color.black.opacity(0.28).ignoresSafeArea() }
            }

            VStack(spacing: 0) {
                header

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        CompanionExpressionImage(emotion: emotion)
                        .frame(
                            width: min(proxy.size.width - 12, 410),
                            height: min(proxy.size.height * 0.72, 450)
                        )
                        .onTapGesture {
                            let sequence: [CompanionEmotion] = [
                                .idle, .listening, .thinking, .speaking, .happy,
                                .surprised, .confused, .sad, .angry, .sleepy
                            ]
                            let current = sequence.firstIndex(of: emotion) ?? 0
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                emotion = sequence[(current + 1) % sequence.count]
                            }
                            message = "Biểu cảm: " + emotion.label
                        }

                        Spacer(minLength: 6)

                        VStack(alignment: .leading, spacing: 7) {
                            Label(statusText, systemImage: statusIcon)
                                .font(.caption.weight(.semibold))

                            Text(
                                message
                                ?? viewModel.messages.last(where: { $0.role == .assistant })?.content
                                ?? "Chào anh! Mình trò chuyện nhé."
                            )
                            .font(.subheadline)
                            .lineLimit(2)
                        }
                        .foregroundStyle(.white)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(activeTheme.accent.opacity(0.18), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                controls
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDiagnosticLog) { diagnosticLogSheet }
        .onChange(of: liveManager.lines.count) { _ in
            guard let line = liveManager.lines.last else { return }
            addDiagnostic("[VOICE] Có dòng thoại mới, vai trò: \(line.role)")
            message = line.text
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                // Keep the conversational emotion while the mouth animation runs.
                emotion = line.role == .assistant ? .happy : .thinking
            }
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            addDiagnostic("[VOICE] AI đang nói: \(speaking)")
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                if speaking {
                    // Speech is a mouth animation, not a facial emotion.
                    if emotion == .idle || emotion == .listening || emotion == .thinking {
                        emotion = .speaking
                    }
                } else if emotion == .speaking {
                    emotion = liveManager.state == .live ? .listening : .idle
                }
            }
        }
        .onChange(of: liveManager.state) { state in
            addDiagnostic("[VOICE] Trạng thái: \(String(describing: state))")
            guard !liveManager.aiSpeaking else { return }
            switch state {
            case .idle:
                emotion = .idle
            case .connecting:
                emotion = .thinking
            case .live:
                emotion = .listening
            }
        }
        .onDisappear {
            liveManager.end()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeTheme.accent.opacity(0.22), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Đóng avatar")

            VStack(alignment: .leading, spacing: 3) {
                Text("ChatAI Companion")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(viewModel.selectedProvider.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button { showDiagnosticLog = true } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeTheme.accent.opacity(0.22), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Xem và sao chép log")

            Button { nightMode.toggle() } label: {
                Image(systemName: nightMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeTheme.accent.opacity(0.22), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Đổi chế độ nền")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var diagnosticLogSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Log chẩn đoán Chat Voice").font(.headline)
                Text("Ghi trạng thái giọng nói và kiểm tra ảnh biểu cảm. Không ghi API key.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text((diagnosticLogs + imageDiagnosticLines).joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled).padding(12)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    UIPasteboard.general.string = (diagnosticLogs + imageDiagnosticLines).joined(separator: "\n")
                } label: {
                    Label("Sao chép log", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }.buttonStyle(.borderedProminent)
            }.padding()
                .navigationTitle("Log Chat Voice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { showDiagnosticLog = false }
                } }
        }
    }

    private var imageDiagnosticLines: [String] {
        let names = ["companion_angry.png", "companion_happy.png", "companion_neutral.png",
            "companion_sleepy.png", "companion_speaking.png", "companion_surprised.png",
            "companion_thinking.png", "companion_wink.png"]
        return names.map { name in
            let found = Bundle.main.url(forResource: name, withExtension: nil) != nil
                || Bundle.main.url(forResource: String(name.dropLast(4)), withExtension: "jpg", subdirectory: "FaceExpressions") != nil
            return "[IMAGE] \(name): \(found ? "OK" : "MISSING")"
        } + ["[IMAGE] Biểu cảm hiện tại: \(emotion.label)",
             "[VOICE] Trạng thái hiện tại: \(String(describing: liveManager.state))"]
    }

    private func addDiagnostic(_ line: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        diagnosticLogs.append("[\(timestamp)] \(line)")
        if diagnosticLogs.count > 150 { diagnosticLogs.removeFirst(diagnosticLogs.count - 150) }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                if liveManager.state == .idle {
                    startLive()
                } else {
                    liveManager.end()
                }
            } label: {
                Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill")
                    .frame(width: 52, height: 52)
                    .background(activeTheme.surface, in: Circle())
                    .overlay(Circle().stroke(activeTheme.accent.opacity(0.24), lineWidth: 1))
            }

            Button {
                if liveManager.state == .idle {
                    startLive()
                }
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
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [activeTheme.accent, activeTheme.accent.opacity(0.78)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .frame(width: 52, height: 52)
                    .background(Color.red.opacity(0.85), in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(activeTheme.background.opacity(0.96))
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
        }
    }

    private var statusIcon: String {
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
        }
    }
}

private enum CompanionEmotion: CaseIterable {
    case idle, listening, thinking, speaking, happy, surprised, confused, sad, angry, sleepy

    var label: String {
        switch self {
        case .idle: "Bình thường"
        case .listening: "Đang nghe"
        case .thinking: "Đang suy nghĩ"
        case .speaking: "Đang nói"
        case .happy: "Vui"
        case .surprised: "Ngạc nhiên"
        case .confused: "Bối rối"
        case .sad: "Buồn"
        case .angry: "Tức giận"
        case .sleepy: "Buồn ngủ"
        }
    }
}

private struct ApprovedRobotHead: View {
    let emotion: CompanionEmotion
    let isSpeaking: Bool
    let onTap: () -> Void

    @State private var blink = false
    @State private var floating = false
    @State private var gaze: CGFloat = 0
    @State private var mouthOpen = false
    @State private var rotationAngle: CGFloat = 0
    @State private var dragStartAngle: CGFloat?
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 410, geo.size.height / 450)

            ZStack {
                Circle()
                    .fill(activeTheme.accent.opacity(0.10))
                    .frame(width: 350 * scale, height: 350 * scale)
                    .blur(radius: 46)

                // Rear translucent fins.
                SideFin(scale: scale, mirrored: false)
                    .frame(width: 92 * scale, height: 122 * scale)
                    .position(x: 55 * scale, y: 286 * scale)

                SideFin(scale: scale, mirrored: true)
                    .frame(width: 92 * scale, height: 122 * scale)
                    .position(x: 355 * scale, y: 286 * scale)

                // Pearl-white head with a distinct pastel-pink outer bezel.
                HelmetShape()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(red: 0.985, green: 0.94, blue: 0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 354 * scale, height: 282 * scale)
                    .overlay(
                        HelmetShape()
                            .stroke(activeTheme.accent.opacity(0.88), lineWidth: 11 * scale)
                    )
                    .overlay(
                        HelmetShape()
                            .stroke(.white.opacity(0.92), lineWidth: 2 * scale)
                            .padding(9 * scale)
                    )
                    .shadow(color: activeTheme.accent.opacity(0.28), radius: 20 * scale, y: 10 * scale)
                    .position(x: 205 * scale, y: 240 * scale)

                // Pale blue shell seams.
                Capsule()
                    .fill(activeTheme.accent.opacity(0.72))
                    .frame(width: 4 * scale, height: 38 * scale)
                    .rotationEffect(.degrees(19))
                    .position(x: 120 * scale, y: 102 * scale)

                Capsule()
                    .fill(activeTheme.accent.opacity(0.72))
                    .frame(width: 4 * scale, height: 38 * scale)
                    .rotationEffect(.degrees(-19))
                    .position(x: 290 * scale, y: 102 * scale)

                // Side ear/headphone modules.
                EarModule(scale: scale)
                    .position(x: 36 * scale, y: 238 * scale)

                EarModule(scale: scale)
                    .position(x: 374 * scale, y: 238 * scale)

                // Two short antennae with pink glowing tips.
                Antenna(scale: scale, mirrored: false)
                    .position(x: 139 * scale, y: 57 * scale)
                Antenna(scale: scale, mirrored: true)
                    .position(x: 271 * scale, y: 57 * scale)

                // Deep black OLED-style visor.
                VisorShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.018, green: 0.022, blue: 0.035), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 308 * scale, height: 194 * scale)
                    .overlay(
                        VisorShape()
                            .stroke(activeTheme.accent.opacity(0.82), lineWidth: 5 * scale)
                    )
                    .overlay(
                        VisorShape()
                            .stroke(.white.opacity(0.12), lineWidth: 2 * scale)
                            .padding(7 * scale)
                    )
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(.white.opacity(0.22))
                            .frame(width: 60 * scale, height: 13 * scale)
                            .rotationEffect(.degrees(-28))
                            .offset(x: 43 * scale, y: 20 * scale)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 12 * scale, y: 8 * scale)
                    .position(x: 205 * scale, y: 239 * scale)

                // Large glassy cyan eyes.
                ConceptEye(
                    scale: scale,
                    height: blink ? 4 : eyeHeight,
                    pupilOffset: gaze,
                    emotion: emotion
                )
                .position(x: 142 * scale, y: 232 * scale + eyeOffsetY)

                ConceptEye(
                    scale: scale,
                    height: blink ? 4 : eyeHeight,
                    pupilOffset: gaze,
                    emotion: emotion
                )
                .position(x: 268 * scale, y: 232 * scale + eyeOffsetY)

                Brow(scale: scale, side: -1, emotion: emotion)
                    .position(x: 142 * scale, y: 191 * scale)

                Brow(scale: scale, side: 1, emotion: emotion)
                    .position(x: 268 * scale, y: 191 * scale)

                // Cheeks react visibly to the current emotion.
                Capsule()
                    .fill(cheekColor)
                    .frame(width: (emotion == .happy ? 39 : 31) * scale, height: (emotion == .happy ? 15 : 10) * scale)
                    .rotationEffect(.degrees(-6))
                    .shadow(color: cheekColor.opacity(0.55), radius: (emotion == .happy ? 8 : 4) * scale)
                    .position(x: 94 * scale, y: 294 * scale)

                Capsule()
                    .fill(cheekColor)
                    .frame(width: (emotion == .happy ? 39 : 31) * scale, height: (emotion == .happy ? 15 : 10) * scale)
                    .rotationEffect(.degrees(6))
                    .shadow(color: cheekColor.opacity(0.55), radius: (emotion == .happy ? 8 : 4) * scale)
                    .position(x: 316 * scale, y: 294 * scale)

                RobotMouth(
                    scale: scale,
                    emotion: emotion,
                    speaking: isSpeaking,
                    open: mouthOpen
                )
                .position(x: 205 * scale, y: 294 * scale)
            }
            .frame(width: 410 * scale, height: 450 * scale)
            .offset(y: floating ? -3 * scale : 3 * scale)
            .rotation3DEffect(
                .degrees(Double(rotationAngle)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if isSpeaking {
                            rotationAngle = 0
                            dragStartAngle = nil
                            return
                        }
                        if dragStartAngle == nil {
                            dragStartAngle = rotationAngle
                        }
                        let start = dragStartAngle ?? rotationAngle
                        rotationAngle = min(38, max(-38, start + value.translation.width * 0.7))
                    }
                    .onEnded { _ in
                        dragStartAngle = nil
                    }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    floating = true
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    gaze = 2.5
                }

                Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 3_400_000_000)
                        withAnimation(.easeInOut(duration: 0.07)) { blink = true }
                        try? await Task.sleep(nanoseconds: 90_000_000)
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { blink = false }
                    }
                }
            }
            .onChange(of: isSpeaking) { speaking in
                if speaking {
                    dragStartAngle = nil
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                        rotationAngle = 0
                    }
                    withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) {
                        mouthOpen = true
                    }
                } else {
                    mouthOpen = false
                }
            }
        }
    }

    private var eyeHeight: CGFloat {
        switch emotion {
        case .surprised: 82
        case .sleepy: 24
        case .happy: 43
        case .angry: 48
        case .sad: 58
        case .confused: 64
        case .thinking: 58
        case .listening: 70
        case .speaking: 66
        case .idle: 64
        }
    }

    private var eyeOffsetY: CGFloat {
        switch emotion {
        case .happy: 5
        case .sad: 5
        case .sleepy: 10
        case .surprised: -4
        default: 0
        }
    }

    private var cheekColor: Color {
        switch emotion {
        case .sad: Color(red: 0.48, green: 0.62, blue: 1).opacity(0.95)
        case .angry: Color(red: 1, green: 0.20, blue: 0.34)
        case .surprised: Color(red: 1, green: 0.58, blue: 0.72)
        case .happy: Color(red: 1, green: 0.25, blue: 0.63)
        case .sleepy: Color(red: 0.76, green: 0.47, blue: 0.80)
        default: Color(red: 1, green: 0.38, blue: 0.67)
        }
    }
}

private struct HelmetShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        p.move(to: CGPoint(x: w * 0.18, y: h * 0.13))
        p.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.13),
            control1: CGPoint(x: w * 0.32, y: -h * 0.01),
            control2: CGPoint(x: w * 0.68, y: -h * 0.01)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.43),
            control1: CGPoint(x: w * 0.94, y: h * 0.18),
            control2: CGPoint(x: w * 0.98, y: h * 0.30)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.82),
            control1: CGPoint(x: w * 0.97, y: h * 0.58),
            control2: CGPoint(x: w * 0.96, y: h * 0.72)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.67, y: h * 0.95),
            control1: CGPoint(x: w * 0.82, y: h * 0.93),
            control2: CGPoint(x: w * 0.73, y: h * 0.98)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.33, y: h * 0.95),
            control1: CGPoint(x: w * 0.58, y: h * 0.98),
            control2: CGPoint(x: w * 0.42, y: h * 0.98)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.82),
            control1: CGPoint(x: w * 0.27, y: h * 0.98),
            control2: CGPoint(x: w * 0.18, y: h * 0.93)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.04, y: h * 0.43),
            control1: CGPoint(x: w * 0.02, y: h * 0.72),
            control2: CGPoint(x: w * 0.03, y: h * 0.58)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.13),
            control1: CGPoint(x: w * 0.02, y: h * 0.30),
            control2: CGPoint(x: w * 0.06, y: h * 0.18)
        )
        p.closeSubpath()
        return p
    }
}

private struct VisorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        p.move(to: CGPoint(x: w * 0.18, y: h * 0.03))
        p.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.03),
            control1: CGPoint(x: w * 0.33, y: -h * 0.01),
            control2: CGPoint(x: w * 0.67, y: -h * 0.01)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.98, y: h * 0.34),
            control1: CGPoint(x: w * 0.96, y: h * 0.12),
            control2: CGPoint(x: w * 1.01, y: h * 0.22)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.91, y: h * 0.78),
            control1: CGPoint(x: w * 0.98, y: h * 0.55),
            control2: CGPoint(x: w * 0.96, y: h * 0.70)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.77, y: h * 0.95),
            control1: CGPoint(x: w * 0.88, y: h * 0.87),
            control2: CGPoint(x: w * 0.84, y: h * 0.96)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.23, y: h * 0.95),
            control1: CGPoint(x: w * 0.70, y: h * 0.96),
            control2: CGPoint(x: w * 0.30, y: h * 0.96)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.09, y: h * 0.78),
            control1: CGPoint(x: w * 0.16, y: h * 0.96),
            control2: CGPoint(x: w * 0.12, y: h * 0.87)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.02, y: h * 0.34),
            control1: CGPoint(x: w * 0.04, y: h * 0.70),
            control2: CGPoint(x: w * 0.02, y: h * 0.55)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.03),
            control1: CGPoint(x: -w * 0.01, y: h * 0.22),
            control2: CGPoint(x: w * 0.04, y: h * 0.12)
        )
        p.closeSubpath()
        return p
    }
}

private struct ConceptEye: View {
    let scale: CGFloat
    let height: CGFloat
    let pupilOffset: CGFloat
    let emotion: CompanionEmotion

    var body: some View {
        let width: CGFloat = emotion == .surprised ? 64 : (emotion == .sleepy ? 53 : 57)
        let eyeColor: Color = emotion == .sad
            ? Color(red: 0.35, green: 0.58, blue: 1)
            : (emotion == .angry
                ? Color(red: 1, green: 0.22, blue: 0.42)
                : (emotion == .happy
                    ? Color(red: 0.28, green: 1, blue: 0.82)
                    : Color(red: 0.12, green: 0.96, blue: 1)))

        ZStack {
            Ellipse()
                .fill(eyeColor.opacity(0.30))
                .frame(width: (width + 28) * scale, height: (height + 28) * scale)
                .blur(radius: 9 * scale)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            eyeColor,
                            Color(red: 0, green: 0.30, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width * scale, height: height * scale)
                .overlay(
                    Ellipse()
                        .stroke(eyeColor.opacity(0.95), lineWidth: 2 * scale)
                )
                .shadow(color: eyeColor.opacity(0.90), radius: emotion == .surprised ? 15 * scale : 8 * scale)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.72, blue: 0.82), Color(red: 0.01, green: 0.25, blue: 0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.70 * scale, height: height * 0.78 * scale)
                .offset(x: pupilOffset * scale)

            Ellipse()
                .fill(Color(red: 0.002, green: 0.02, blue: 0.03))
                .frame(width: width * 0.36 * scale, height: height * 0.58 * scale)
                .offset(x: pupilOffset * scale)

            Circle()
                .fill(.white)
                .frame(width: width * 0.25 * scale, height: width * 0.25 * scale)
                .offset(x: -width * 0.17 * scale, y: -height * 0.25 * scale)

            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: width * 0.11 * scale, height: width * 0.11 * scale)
                .offset(x: width * 0.16 * scale, y: height * 0.20 * scale)

            Capsule()
                .fill(.white.opacity(0.48))
                .frame(width: width * 0.24 * scale, height: height * 0.07 * scale)
                .rotationEffect(.degrees(-30))
                .offset(x: -width * 0.18 * scale, y: -height * 0.39 * scale)
        }
    }
}

private struct Brow: View {
    let scale: CGFloat
    let side: CGFloat
    let emotion: CompanionEmotion

    var body: some View {
        Capsule()
            .fill(Color(red: 0.32, green: 0.90, blue: 1).opacity(0.78))
            .frame(width: 43 * scale, height: 5 * scale)
            .rotationEffect(.degrees(angle))
            .shadow(color: .cyan.opacity(0.55), radius: 4 * scale)
    }

    private var angle: Double {
        switch emotion {
        case .angry: return side < 0 ? 32 : -32
        case .sad: return side < 0 ? -22 : 22
        case .confused: return side < 0 ? -20 : 22
        case .thinking: return side < 0 ? -15 : 10
        case .surprised: return side < 0 ? -12 : 12
        case .happy: return side < 0 ? 9 : -9
        case .sleepy: return side < 0 ? 12 : -12
        default: return side < 0 ? -5 : 5
        }
    }
}

private struct RobotMouth: View {
    let scale: CGFloat
    let emotion: CompanionEmotion
    let speaking: Bool
    let open: Bool

    var body: some View {
        Group {
            if speaking && emotion != .surprised {
                Capsule()
                    .fill(Color.black)
                    .frame(width: (open ? 38 : 28) * scale, height: (open ? 23 : 10) * scale)
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 1, green: 0.44, blue: 0.72), lineWidth: 3 * scale)
                    )
                    .shadow(color: .pink.opacity(0.70), radius: 7 * scale)
            } else if emotion == .surprised {
                Circle()
                    .fill(Color.black)
                    .frame(width: 25 * scale, height: 29 * scale)
                    .overlay(Circle().stroke(Color(red: 1, green: 0.44, blue: 0.72), lineWidth: 3 * scale))
            } else {
                switch emotion {
                case .surprised:
                    Circle()
                        .fill(Color.black)
                        .frame(width: 25 * scale, height: 29 * scale)
                        .overlay(Circle().stroke(Color(red: 1, green: 0.44, blue: 0.72), lineWidth: 3 * scale))
                case .sad:
                    HStack(spacing: -2 * scale) {
                        Capsule().fill(Color.pink).frame(width: 15 * scale, height: 5 * scale).rotationEffect(.degrees(-24))
                        Capsule().fill(Color.pink).frame(width: 15 * scale, height: 5 * scale).rotationEffect(.degrees(24))
                    }
                case .happy:
                    Capsule()
                        .fill(Color.pink)
                        .frame(width: 34 * scale, height: 9 * scale)
                        .overlay(Capsule().stroke(Color(red: 1, green: 0.44, blue: 0.72), lineWidth: 2 * scale))
                case .angry:
                    HStack(spacing: -3 * scale) {
                        Capsule().fill(Color.pink).frame(width: 18 * scale, height: 5 * scale).rotationEffect(.degrees(-12))
                        Capsule().fill(Color.pink).frame(width: 18 * scale, height: 5 * scale).rotationEffect(.degrees(12))
                    }
                case .confused:
                    Capsule()
                        .fill(Color.pink)
                        .frame(width: 23 * scale, height: 5 * scale)
                        .rotationEffect(.degrees(-12))
                case .sleepy:
                    Capsule().fill(Color.pink.opacity(0.8)).frame(width: 25 * scale, height: 4 * scale)
                case .thinking:
                    Circle().fill(Color.pink).frame(width: 8 * scale, height: 8 * scale)
                case .listening:
                    Capsule().fill(Color.pink).frame(width: 22 * scale, height: 5 * scale)
                case .idle, .speaking:
                    HStack(spacing: -2 * scale) {
                        Capsule().fill(Color.pink).frame(width: 14 * scale, height: 5 * scale).rotationEffect(.degrees(25))
                        Capsule().fill(Color.pink).frame(width: 14 * scale, height: 5 * scale).rotationEffect(.degrees(-25))
                    }
                }
            }
        }
    }
}

private struct EarModule: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(red: 0.82, green: 0.94, blue: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 82 * scale, height: 82 * scale)
                .overlay(Circle().stroke(Color(red: 1, green: 0.58, blue: 0.80), lineWidth: 7 * scale))

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.47, green: 0.88, blue: 1), Color(red: 0.25, green: 0.64, blue: 0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 54 * scale, height: 54 * scale)
                .overlay(Circle().stroke(Color(red: 1, green: 0.76, blue: 0.89), lineWidth: 4 * scale))

            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 18 * scale, height: 18 * scale)
            Circle()
                .fill(Color(red: 1, green: 0.45, blue: 0.75))
                .frame(width: 8 * scale, height: 8 * scale)
        }
    }
}

private struct Antenna: View {
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.40, green: 0.83, blue: 1))
                .frame(width: 6 * scale, height: 48 * scale)
                .rotationEffect(.degrees(mirrored ? 13 : -13))
                .offset(y: 12 * scale)

            Circle()
                .fill(Color.pink.opacity(0.30))
                .frame(width: 38 * scale, height: 38 * scale)
                .blur(radius: 7 * scale)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(red: 1, green: 0.53, blue: 0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 29 * scale, height: 29 * scale)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2 * scale))

            Circle()
                .fill(.white.opacity(0.75))
                .frame(width: 8 * scale, height: 8 * scale)
                .offset(x: -5 * scale, y: -5 * scale)
        }
    }
}

private struct SideFin: View {
    let scale: CGFloat
    let mirrored: Bool

    var body: some View {
        ZStack {
            FinShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.96), Color(red: 0.54, green: 0.86, blue: 1).opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(FinShape().stroke(Color(red: 1, green: 0.70, blue: 0.87), lineWidth: 4 * scale))

            VStack(spacing: 13 * scale) {
                Capsule().fill(.white.opacity(0.82)).frame(width: 54 * scale, height: 2 * scale)
                Capsule().fill(.white.opacity(0.82)).frame(width: 63 * scale, height: 2 * scale)
                Capsule().fill(.white.opacity(0.82)).frame(width: 48 * scale, height: 2 * scale)
            }
            .rotationEffect(.degrees(mirrored ? 14 : -14))
        }
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }
}

private struct FinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.04))
        p.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.40),
            control1: CGPoint(x: w * 0.96, y: h * 0.00),
            control2: CGPoint(x: w * 1.02, y: h * 0.24)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.96),
            control1: CGPoint(x: w * 0.92, y: h * 0.82),
            control2: CGPoint(x: w * 0.70, y: h * 1.03)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.48),
            control1: CGPoint(x: w * 0.13, y: h * 0.91),
            control2: CGPoint(x: w * -0.03, y: h * 0.62)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.04),
            control1: CGPoint(x: w * 0.18, y: h * 0.12),
            control2: CGPoint(x: w * 0.35, y: h * 0.00)
        )
        p.closeSubpath()
        return p
    }
}


/// Loads bundled expression photos so Chat Voice works without network access.
private struct CompanionExpressionImage: View {
    let emotion: CompanionEmotion

    private var imageName: String {
        switch emotion {
        case .angry: "companion_angry.png"
        case .happy: "companion_happy.png"
        case .speaking: "companion_speaking.png"
        case .surprised: "companion_surprised.png"
        case .thinking, .confused: "companion_thinking.png"
        case .sleepy: "companion_sleepy.png"
        case .sad, .idle, .listening: "companion_neutral.png"
        }
    }

    private var localImage: UIImage? {
    // Direct path — folder reference bundles at FaceExpressions/
    let directURL = Bundle.main.bundleURL
        .appendingPathComponent("FaceExpressions")
        .appendingPathComponent(imageName)
    if FileManager.default.fileExists(atPath: directURL.path) {
        return UIImage(contentsOfFile: directURL.path)
    }
    // Fallback: flat bundle root
    let rootURL = Bundle.main.bundleURL.appendingPathComponent(imageName)
    if FileManager.default.fileExists(atPath: rootURL.path) {
        return UIImage(contentsOfFile: rootURL.path)
    }
    return nil
}

    var body: some View {
        Group {
            if let image = localImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Biểu cảm: \(emotion.label)")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 42))
                    Text("Không tìm thấy ảnh biểu cảm trong ứng dụng")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
