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
    @State private var showAraTestMenu = false
    @State private var selectedAraTestGroup: Int?
    @State private var showDiagnosticLog = false
    @State private var isGestureTestMode = false
    @State private var gestureTestTask: Task<Void, Never>?
    @State private var diagnosticLogs: [String] = ["[INFO] Mở màn hình Chat Voice"]

    var body: some View {
        ZStack {
            ChatAIThemeBackground(theme: activeTheme)

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
        .overlay(alignment: .topTrailing) {
            if showAraTestMenu {
                araTestPopup
                    .padding(.top, 58)
                    .padding(.trailing, 12)
                    .zIndex(10)
            }
        }
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

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    showAraTestMenu.toggle()
                    selectedAraTestGroup = nil
                }
            } label: {
                Image(systemName: "testtube.2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeTheme.accent.opacity(0.22), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Mở menu Test Ara")
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

    private var araTestGroups: [(String, String, [(String, AraAvatarView.Clip)])] {
        [
            ("T. Chuyện", "face.smiling", [
                ("Idle", .idle), ("Nghe", .listening), ("Nghĩ", .thinking),
                ("Nói", .talk), ("Giải thích", .talkExplain),
                ("Đồng cảm", .empathy), ("Ara cười", .laugh), ("Cười", .naturalLaugh)
            ]),
            ("Y. Cầu", "hand.tap", [
                ("Vẫy tay", .wave), ("Đi", .walk), ("Chạy", .run),
                ("Lùi", .walkBackwards), ("Sang trái", .strafeLeft),
                ("Sang phải", .strafeRight), ("Quay trái 45°", .turnLeft45),
                ("Quay trái 90°", .turnLeft90), ("Quay phải 45°", .turnRight45),
                ("Quay phải 90°", .turnRight90), ("Quay 360°", .fullTurn),
                ("Ngồi xuống", .sitDown), ("Ngồi yên", .sitIdle),
                ("Đứng dậy", .standUp), ("Nằm", .lieDown),
                ("Ngủ", .sleep), ("Nhảy", .jumpStart),
                ("Cưỡi ngựa", .rideHorse)
            ])
        ]
    }

    private var araTestPopup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Test")
                    .font(.system(size: 13, weight: .bold))
                Spacer(minLength: 2)
                Button(isGestureTestMode ? "Tắt" : "Bật") {
                    toggleGestureTestMode()
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.bordered)
                .tint(activeTheme.accent)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showAraTestMenu = false
                        selectedAraTestGroup = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(activeTheme.surface, in: Circle())
                }
                .accessibilityLabel("Đóng menu Test")
            }
            .foregroundStyle(.white)

            if let group = selectedAraTestGroup {
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedAraTestGroup = nil
                        }
                    } label: {
                        Label("Test", systemImage: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    Text(araTestGroups[group].0)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.fixed(90)), GridItem(.fixed(90))], spacing: 6) {
                        ForEach(araTestGroups[group].2, id: \.0) { item in
                            Button {
                                runAraTest(item.1)
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    showAraTestMenu = false
                                    selectedAraTestGroup = nil
                                }
                            } label: {
                                Text(item.0)
                                    .font(.system(size: 10, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                    .foregroundStyle(.white)
                                    .frame(width: 90, height: 90)
                                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(activeTheme.accent.opacity(0.18), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            } else {
                HStack(spacing: 8) {
                    araTestGroupButton(index: 0)
                    araTestGroupButton(index: 1)
                }
            }
        }
        .padding(8)
        .frame(width: 202)
        .background(activeTheme.background.opacity(0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(activeTheme.accent.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
    }

    private func araTestGroupButton(index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedAraTestGroup = index
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: araTestGroups[index].1)
                    .font(.system(size: 17, weight: .semibold))
                Text(araTestGroups[index].0)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(activeTheme.accent)
            .frame(width: 90, height: 90)
            .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(activeTheme.accent.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func runAraTest(_ clip: AraAvatarView.Clip) {
        if !isGestureTestMode { toggleGestureTestMode() }
        if clip == .jumpStart { testJumpSequence() }
        else { testAraGesture(clip) }
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
        let duration = araClipDuration(clip)
        addDiagnostic("[ARA TEST] Started: \(clip.rawValue); duration=\(String(format: "%.2f", duration))s; loops=\(clip.loops)")
        guard !clip.loops else { gestureTestTask = nil; return }
        gestureTestTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            catch { return }
            guard isGestureTestMode, avatarClip == clip else { return }
            avatarClip = .idle
            addDiagnostic("[ARA TEST] Finished: \(clip.rawValue); returned to Idle")
            gestureTestTask = nil
        }
    }

    private func testJumpSequence() {
        guard isGestureTestMode else { return }
        gestureTestTask?.cancel()
        cancelExplainGesture()
        cancelEmotionGesture()
        gestureTestTask = Task { @MainActor in
            for clip in [AraAvatarView.Clip.jumpStart, .jumpAir, .jumpLand] {
                guard !Task.isCancelled, isGestureTestMode else { return }
                avatarClip = clip
                let duration = araClipDuration(clip)                addDiagnostic("[ARA TEST] Jump: \(clip.rawValue), \(String(format: "%.2f", duration))s")
                do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
                catch { return }
            }
            guard !Task.isCancelled, isGestureTestMode else { return }
            avatarClip = .idle
            addDiagnostic("[ARA TEST] Jump sequence finished; returned to Idle")
            gestureTestTask = nil
        }
    }

    private func araClipDuration(_ clip: AraAvatarView.Clip) -> TimeInterval {
        guard let url = Bundle.main.url(forResource: "animation-timeline", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clips = root["clips"] as? [[String: Any]],
              let item = clips.first(where: { ($0["name"] as? String)?.caseInsensitiveCompare(clip.rawValue) == .orderedSame }),
              let start = item["start"] as? Double,
              let end = item["end"] as? Double else { return 1.0 }
        return max(0.1, end - start)
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
        let happySignals = ["haha", "😂", "🤣", "😄", "😊", "vui quá", "tuyệt vời", "chúc mừng", "hay quá"]        let surprisedSignals = ["😮", "😲", "bất ngờ", "không ngờ", "thật sao", "wow"]
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