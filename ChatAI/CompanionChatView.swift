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
    @State private var previousAssistantLineIDForTurn: UUID?
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
                    previousAssistantLineIDForTurn = liveManager.lines.dropLast().last(where: { $0.role == .assistant })?.id
                }
                addDiagnostic("[VOICE] Có dòng thoại mới, vai trò: \(line.role)")
            }
            handleLatestTranscript()
        }
        .onChange(of: liveManager.lines.last?.text) { _ in
            handleLatestTranscript()
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            guard !isGestureTestMode else { return }
            addDiagnostic("[VOICE] AI đang nói: \(speaking)")
            if speaking {
                speechStartToken &+= 1
                handleLatestTranscript()
            }
            syncAraLiveState()
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
            guard !isGestureTestMode else { return }
            if !liveManager.aiSpeaking {
                switch state {
                case .idle:
                    emotion = .idle
                case .connecting:
                    emotion = .thinking
                case .live:
                    emotion = .listening
                }
            }
            syncAraLiveState()
        }
        .onDisappear {
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
                            .stroke(activeTheme.accent.opacity(0.22), lineWidth: 1)                    }
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
                ("Đồng cảm", .empathy), ("Ara cười", .laugh), ("Cười", .naturalLaugh),
                ("Vẫy tay", .wave), ("Hoan hô", .cheer), ("Khóc", .cry)
            ])
        ]
    }

    private var araTestPopup: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let group = selectedAraTestGroup {
                HStack(spacing: 5) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedAraTestGroup = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 20, height: 24)
                    }
                    .buttonStyle(.plain)

                    Text(araTestGroups[group].0)
                        .font(.system(size: 11, weight: .semibold))

                    Spacer(minLength: 0)

                    closeAraTestPopupButton
                }
                .foregroundStyle(.white)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(araTestGroups[group].2, id: \.0) { item in
                            Button {
                                runAraTest(item.1)
                            } label: {
                                Text(item.0)
                                    .font(.system(size: 7, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.65)
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(activeTheme.accent.opacity(0.18), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 40)
                }
                .frame(maxHeight: 260)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    closeAraTestPopupButton
                }

                VStack(spacing: 7) {
                    araTestGroupButton(index: 0)

                    Button {
                        runAraBatchTest()
                    } label: {
                        Label("TEST tổng hợp", systemImage: "play.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 86, height: 32)
                            .background(activeTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isGestureTestMode)
                    .opacity(isGestureTestMode ? 0.5 : 1)
                }
            }
        }
        .padding(8)
        .fixedSize(horizontal: true, vertical: true)
        .background(activeTheme.background.opacity(0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(activeTheme.accent.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
    }

    private var closeAraTestPopupButton: some View {
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
        .buttonStyle(.plain)
        .accessibilityLabel("Đóng menu")
    }

    private func araTestGroupButton(index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedAraTestGroup = index
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: araTestGroups[index].1)
                    .font(.system(size: 10, weight: .semibold))
                Text(araTestGroups[index].0)
                    .font(.system(size: 6, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(activeTheme.accent)
            .frame(width: 40, height: 40)
            .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(activeTheme.accent.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func runAraTest(_ clip: AraAvatarView.Clip) {
        beginGestureTestMode()
        testAraGesture(clip)
    }

    private func runAraBatchTest() {
        guard !isGestureTestMode else { return }
        beginGestureTestMode()
        let clips: [AraAvatarView.Clip] = [
            .idle, .wave, .talk, .talkExplain, .listening, .thinking,
            .empathy, .laugh, .naturalLaugh, .cheer, .cry
        ]
        addDiagnostic("[ARA TEST] Batch started: \(clips.count) clips; automatic sequence")

        gestureTestTask = Task { @MainActor in
            for (index, clip) in clips.enumerated() {
                guard !Task.isCancelled, isGestureTestMode else { return }
                avatarClip = clip
                let duration = araClipDuration(clip)
                addDiagnostic(
                    "[ARA TEST] Batch \(index + 1)/\(clips.count): \(clip.rawValue); duration=\(String(format: "%.2f", duration))s; loops=\(clip.loops)"
                )
                do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
                catch { return }
            }
            guard !Task.isCancelled, isGestureTestMode else { return }
            endGestureTestMode()
            addDiagnostic("[ARA TEST] Batch finished: \(clips.count)/\(clips.count); live state restored")
        }
    }

    private func beginGestureTestMode() {
        guard !isGestureTestMode else { return }
        gestureTestTask?.cancel()
        isGestureTestMode = true
        avatarClip = .idle
        addDiagnostic("[ARA TEST] Test started independently; voice session preserved (state=\(liveManager.state))")
    }

    private func endGestureTestMode() {
        gestureTestTask?.cancel()
        gestureTestTask = nil
        isGestureTestMode = false
        avatarClip = liveManager.aiSpeaking ? .talk : (liveManager.state == .live ? .listening : .idle)
        addDiagnostic("[ARA TEST] Test finished; live avatar state restored")
    }

    private func testAraGesture(_ clip: AraAvatarView.Clip) {
        guard isGestureTestMode else { return }
        gestureTestTask?.cancel()
        avatarClip = clip
        let duration = araClipDuration(clip)
        addDiagnostic("[ARA TEST] Started: \(clip.rawValue); duration=\(String(format: "%.2f", duration))s; loops=\(clip.loops)")
        gestureTestTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            catch { return }
            guard isGestureTestMode, avatarClip == clip else { return }
            endGestureTestMode()
            addDiagnostic("[ARA TEST] Finished: \(clip.rawValue)")
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

    private func syncAraLiveState() {
        guard !isGestureTestMode else { return }

        let nextClip: AraAvatarView.Clip
        if liveManager.aiSpeaking {
            nextClip = .talk
        } else {
            switch liveManager.state {
            case .idle: nextClip = .idle
            case .connecting: nextClip = .thinking
            case .live: nextClip = .listening
            }
        }

        guard avatarClip != nextClip else { return }
        avatarClip = nextClip
        addDiagnostic("[ARA STATE] Live animation: \(nextClip.rawValue)")
    }

    private func handleLatestTranscript() {
        guard !isGestureTestMode, let line = liveManager.lines.last else { return }
        message = line.text
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            emotion = line.role == .user ? .listening : emotionForAssistantText(line.text)
        }
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