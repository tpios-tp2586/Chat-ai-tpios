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
    @State private var avatarClip: AraAvatarView.Clip = .idle
    @State private var didTriggerExplainGesture = false
    @State private var didTriggerContextGestureForTurn = false
    @State private var previousAssistantLineIDForTurn: UUID?
    @State private var explainGestureGeneration = UUID()
    @State private var explainGestureTask: Task<Void, Never>?
    @State private var emotionGestureTask: Task<Void, Never>?
    @State private var emotionGestureGeneration = UUID()
    @State private var speechStartToken = 0
    @State private var message: String?
    @State private var nightMode = false
    @State private var showDiagnosticLog = false
    @State private var isGestureTestMode = false
    @State private var gestureTestTask: Task<Void, Never>?
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
                        ZStack {
                            AraAvatarView(
                                clip: avatarClip,
                                resetToFrontToken: speechStartToken,
                                repeatForTesting: isGestureTestMode
                            ) { log in
                                addDiagnostic(log)
                            }

                            if isGestureTestMode {
                                gestureTestControls
                            }
                        }
                        .frame(
                            width: min(proxy.size.width - 12, 410),
                            height: min(proxy.size.height * 0.72, 450)
                        )

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
            if let line = liveManager.lines.last {
                if line.role == .user {
                    didTriggerExplainGesture = false
                    didTriggerContextGestureForTurn = false
                    previousAssistantLineIDForTurn = liveManager.lines.dropLast().last(where: { $0.role == .assistant })?.id
                }
                addDiagnostic("[VOICE] Có dòng thoại mới, vai trò: \(line.role)")
            }
            handleLatestTranscript()
        }
        .onChange(of: liveManager.lines.last?.text) { _ in
            handleLatestTranscript()
        }
        .onChange(of: liveManager.faceExpression) { expression in
            applyAraEmotion(expression)
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            guard !isGestureTestMode else { return }
            addDiagnostic("[VOICE] AI đang nói: \(speaking)")
            if speaking {
                cancelExplainGesture()
                speechStartToken &+= 1
                avatarClip = .talk
                handleLatestTranscript()
            } else {
                cancelExplainGesture()
                cancelEmotionGesture()
                avatarClip = liveManager.state == .live ? .listening : .idle
            }
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
            guard !isGestureTestMode, !liveManager.aiSpeaking else { return }
            switch state {
            case .idle:
                emotion = .idle
            case .connecting:
                emotion = .thinking
                avatarClip = .thinking
            case .live:
                emotion = .listening
                avatarClip = .wave
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    if liveManager.state == .live && !liveManager.aiSpeaking { avatarClip = .listening }
                }
            }
        }
        .onDisappear {
            cancelExplainGesture()
            cancelEmotionGesture()
            gestureTestTask?.cancel()
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

            Button { toggleGestureTestMode() } label: {
                Image(systemName: isGestureTestMode ? "xmark" : "figure.stand")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeTheme.accent.opacity(0.22), lineWidth: 1)
                    }
            }
            .accessibilityLabel(isGestureTestMode ? "Đóng chế độ test Ara" : "Thử cử chỉ Ara")

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
                Text("Ghi trạng thái giọng nói và tải mô hình Ara. Không ghi API key.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(diagnosticLogs.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled).padding(12)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    UIPasteboard.general.string = diagnosticLogs.joined(separator: "\n")
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

    private var gestureTestControls: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Label("CHẾ ĐỘ TEST", systemImage: "hand.tap")
                    .font(.caption2.weight(.bold))
                Spacer()
                Button("Xong") { toggleGestureTestMode() }
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer(minLength: 8)

            HStack(alignment: .center) {
                VStack(spacing: 7) {
                    gestureTestChip("Wave", clip: .wave)
                    gestureTestChip("Talk", clip: .talk)
                    gestureTestChip("Explain", clip: .talkExplain)
                    gestureTestChip("Listen", clip: .listening)
                    gestureTestChip("Thinking", clip: .thinking)
                    gestureTestChip("Empathy", clip: .empathy)
                }

                Spacer(minLength: 0)

                VStack(spacing: 7) {
                    gestureTestChip("AraLaugh", clip: .laugh)
                    gestureTestChip("Laugh", clip: .naturalLaugh)
                    gestureTestChip("Cheer", clip: .cheer)
                    gestureTestChip("Cry", clip: .cry)
                    gestureTestChip("Idle", clip: .idle)
                }
            }

            Spacer(minLength: 8)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(5)
    }

    private func gestureTestChip(_ title: String, clip: AraAvatarView.Clip) -> some View {
        Button {
            testAraGesture(clip)
        } label: {
            HStack(spacing: 4) {
                if avatarClip == clip {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(title)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(width: 82)
            .background(
                avatarClip == clip ? activeTheme.accent : activeTheme.surface.opacity(0.96),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Test Ara: \(title)")
    }

    private func toggleGestureTestMode() {
        if isGestureTestMode {
            gestureTestTask?.cancel()
            gestureTestTask = nil
            isGestureTestMode = false
            avatarClip = .idle
            addDiagnostic("[ARA TEST] Test mode closed")
            return
        }

        if liveManager.state != .idle {
            liveManager.end()
        }
        cancelExplainGesture()
        cancelEmotionGesture()
        gestureTestTask?.cancel()
        isGestureTestMode = true
        avatarClip = .idle
        addDiagnostic("[ARA TEST] Test mode opened; voice session stopped")
    }

    private func testAraGesture(_ clip: AraAvatarView.Clip) {
        guard isGestureTestMode else { return }
        gestureTestTask?.cancel()
        cancelExplainGesture()
        cancelEmotionGesture()
        avatarClip = clip
        addDiagnostic("[ARA TEST] Started: \(clip.rawValue); repeat window=7s")
        gestureTestTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 7_000_000_000)
            } catch {
                return
            }
            guard isGestureTestMode, avatarClip == clip else { return }
            avatarClip = .idle
            addDiagnostic("[ARA TEST] Finished: \(clip.rawValue); returned to Idle")
            gestureTestTask = nil
        }
    }

    private func applyAraEmotion(_ expression: RobotFaceExpression) {
        guard !isGestureTestMode, avatarClip != .wave && avatarClip != .talkExplain else { return }
        switch expression {
        case .listening:
            avatarClip = .listening
        case .thinking, .confused:
            avatarClip = .thinking
        case .speaking:
            avatarClip = .talk
        case .happy:
            playAraLaugh()
        case .sad:
            avatarClip = .empathy
        case .idle, .surprised, .angry, .sleepy:
            break
        }
    }

    private func playAraLaugh(reason: String = "happy mood") {
        emotionGestureTask?.cancel()
        let generation = UUID()
        emotionGestureGeneration = generation
        avatarClip = .laugh
        addDiagnostic("[ARA] AraLaugh triggered: \(reason)")
        emotionGestureTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 2_400_000_000)
            } catch {
                return
            }
            guard emotionGestureGeneration == generation, avatarClip == .laugh else { return }
            avatarClip = liveManager.aiSpeaking ? .talk : (liveManager.state == .live ? .listening : .idle)
            emotionGestureTask = nil
        }
    }

    private func playAraEmpathy(reason: String) {
        emotionGestureTask?.cancel()
        let generation = UUID()
        emotionGestureGeneration = generation
        avatarClip = .empathy
        addDiagnostic("[ARA] AraEmpathy triggered: \(reason)")
        emotionGestureTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 2_400_000_000)
            } catch {
                return
            }
            guard emotionGestureGeneration == generation, avatarClip == .empathy else { return }
            avatarClip = liveManager.aiSpeaking ? .talk : (liveManager.state == .live ? .listening : .idle)
            emotionGestureTask = nil
        }
    }

    private func cancelEmotionGesture() {
        emotionGestureGeneration = UUID()
        emotionGestureTask?.cancel()
        emotionGestureTask = nil
    }

    private func handleLatestTranscript() {
        guard !isGestureTestMode, let line = liveManager.lines.last else { return }
        message = line.text
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            emotion = line.role == .user ? .listening : emotionForAssistantText(line.text)
        }

        guard line.role == .assistant,
              line.id != previousAssistantLineIDForTurn,
              liveManager.aiSpeaking,
              !didTriggerExplainGesture else { return }

        let wordCount = line.text.split(whereSeparator: { $0.isWhitespace }).count
        guard let reason = explainCueReason(line.text) else {
            addDiagnostic("[ARA] TalkExplain skipped: no explanation cue; chars=\(line.text.count), words=\(wordCount)")
            guard !didTriggerContextGestureForTurn,
                  let cue = contextGestureCue(line.text) else { return }
            didTriggerContextGestureForTurn = true
            if cue.clip == .empathy {
                playAraEmpathy(reason: cue.reason)
            } else {
                playAraLaugh(reason: cue.reason)
            }
            return
        }

        didTriggerExplainGesture = true
        cancelExplainGesture()
        let generation = UUID()
        explainGestureGeneration = generation
        avatarClip = .talkExplain
        addDiagnostic("[ARA] TalkExplain triggered: \(reason); chars=\(line.text.count), words=\(wordCount)")
        explainGestureTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 2_800_000_000)
            } catch {
                return
            }
            guard explainGestureGeneration == generation,
                  liveManager.aiSpeaking,
                  avatarClip == .talkExplain else { return }
            avatarClip = .talk
            addDiagnostic("[ARA] TalkExplain finished; returned to Talk")
            explainGestureTask = nil
        }
    }

    private func cancelExplainGesture() {
        explainGestureGeneration = UUID()
        explainGestureTask?.cancel()
        explainGestureTask = nil
    }

    private func normalizedAraCueText(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
    }

    private func explainCueReason(_ text: String) -> String? {
        let value = normalizedAraCueText(text)
        let cues = [
            "de em giai thich", "giai thich", "noi ro", "cu the", "vi du", "chang han",
            "dau tien", "thu nhat", "thu hai", "thu ba", "tiep theo", "tom lai", "ket luan",
            "quan trong", "nguyen nhan", "ly do", "bao gom", "nghia la", "phan tich",
            "huong dan", "cac buoc", "buoc 1", "so sanh", "vi vay", "do do", "boi vi",
            "theo", "that ra", "chinh la",
            "can lam nhu sau", "minh cung xem", "co the hieu", "dieu nay co nghia",
            "let me explain", "for example", "for instance", "first", "next", "in summary",
            "the reason", "because", "this means", "to compare", "step 1", "here is how"
        ]
        if let cue = cues.first(where: { value.contains($0) }) {
            return "cue=\(cue)"
        }

        let listItems = text.split(separator: "\n").filter { line in
            let item = line.trimmingCharacters(in: .whitespaces)
            return ["- ", "• ", "* "].contains(where: item.hasPrefix)
                || item.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
        }
        return listItems.count >= 2 ? "structured list (\(listItems.count) items)" : nil
    }

    private func contextGestureCue(_ text: String) -> (clip: AraAvatarView.Clip, reason: String)? {
        let value = normalizedAraCueText(text)
        let empathyCues = ["hieu roi", "cam thong", "kho qua", "buon", "lo lang", "thong cam", "dung lo"]
        if let cue = empathyCues.first(where: { value.contains($0) }) {
            return (.empathy, "cue=\(cue)")
        }
        let laughCues = ["ha ha", "hi hi", "vui", "buon cuoi", "hai", "thi ra"]
        if let cue = laughCues.first(where: { value.contains($0) }) {
            return (.laugh, "cue=\(cue)")
        }
        return nil
    }

    private func emotionForAssistantText(_ text: String) -> CompanionEmotion {
        let value = text.lowercased()
        let happySignals = ["haha", "😂", "🤣", "😄", "😊", "vui quá", "tuyệt vời", "chúc mừng", "hay quá"]
        let surprisedSignals = ["😮", "😲", "bất ngờ", "không ngờ", "thật sao", "wow"]
        let winkSignals = ["😉", "😜", "đùa thôi", "trêu anh"]
        if winkSignals.contains(where: value.contains) { return .happy }
        if surprisedSignals.contains(where: value.contains) { return .surprised }
        if happySignals.contains(where: value.contains) { return .happy }
        return liveManager.aiSpeaking ? .speaking : .idle
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
        previousAssistantLineIDForTurn = liveManager.lines.last(where: { $0.role == .assistant })?.id
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

