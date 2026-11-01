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
    @State private var showExpressionTests = false
    @State private var showActionTests = false
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
        .sheet(isPresented: $showExpressionTests) { expressionTestSheet }
        .sheet(isPresented: $showActionTests) { actionTestSheet }
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
                if isGestureTestMode {
                    toggleGestureTestMode()
                } else {
                    toggleGestureTestMode()
                    showExpressionTests = true
                }
            } label: {
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

            if isGestureTestMode {
                Button { showExpressionTests = true } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activeTheme.accent)
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Biểu cảm & lời nói")

                Button { showActionTests = true } label: {
                    Image(systemName: "figure.run")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activeTheme.accent)
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Theo yêu cầu")
            }

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

    private var expressionTestSheet: some View {
        testSheet(title: "Biểu cảm & lời nói", groups: [
            ("Nói chuyện", [("Idle", AraAvatarView.Clip.idle), ("Talk", .talk), ("TalkExplain", .talkExplain)]),
            ("Biểu cảm", [("Wave", .wave), ("Laugh", .naturalLaugh)])
        ])
    }

    private var actionTestSheet: some View {
        testSheet(title: "Theo yêu cầu", groups: [
            ("Di chuyển", [("Walk", .walk), ("Run", .run), ("Walk backwards", .walkBackwards), ("Strafe left", .strafeLeft), ("Strafe right", .strafeRight)]),
            ("Xoay", [("Turn left 45°", .turnLeft45), ("Turn left 90°", .turnLeft90), ("Turn right 45°", .turnRight45), ("Turn right 90°", .turnRight90), ("Full turn 360°", .fullTurn)]),
            ("Tư thế", [("Idle / nghỉ", .idle), ("Sit down (chair)", .sitDown), ("Sit idle (chair)", .sitIdle), ("Stand up (chair)", .standUp), ("Lie down", .lieDown), ("Sleep", .sleep)]),
            ("Nhảy", [("Jump sequence", .jumpStart)]),
            ("Cử chỉ & phương tiện", [("Wave", .wave), ("Laugh", .naturalLaugh), ("Ride horse (trot)", .rideHorse)])
        ])
    }

    private func testSheet(title: String, groups: [(String, [(String, AraAvatarView.Clip)])]) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups.indices, id: \.self) { groupIndex in
                        let group = groups[groupIndex]
                        VStack(alignment: .leading, spacing: 9) {
                            Text(group.0).font(.subheadline.weight(.semibold))
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(group.1.indices, id: \.self) { itemIndex in
                                    let item = group.1[itemIndex]
                                    Button {
                                        if item.1 == .jumpStart {
                                            testJumpSequence()
                                        } else {
                                            testAraGesture(item.1)
                                        }
                                    } label: {
                                        Text(item.0).frame(maxWidth: .infinity).padding(.vertical, 11)
                                            .background(avatarClip == item.1 ? activeTheme.accent : activeTheme.surface,
                                                        in: RoundedRectangle(cornerRadius: 12))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }.padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { showExpressionTests = false; showActionTests = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleGestureTestMode() {
        if isGestureTestMode {
            gestureTestTask?.cancel()
            gestureTestTask = nil
            isGestureTestMode = false
            showExpressionTests = false
            showActionTests = false
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
                let duration = araClipDuration(clip)
                addDiagnostic("[ARA TEST] Jump: \(clip.rawValue), \(String(format: "%.2f", duration))s")
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

    private var statusText: String {
        if isGestureTestMode { return "Đang test Ara" }
        if liveManager.aiSpeaking { return "Ara đang nói" }
        switch liveManager.state {
        case .idle: return "Sẵn sàng"
        case .connecting: return "Đang kết nối"
        case .live: return "Đang nghe"
        }
    }

    private var statusIcon: String {
        if isGestureTestMode { return "hand.tap" }
        if liveManager.aiSpeaking { return "waveform" }
        switch liveManager.state {
        case .idle: return "checkmark.circle"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .live: return "ear"
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button { liveManager.toggle() } label: {
                Image(systemName: liveManager.state == .idle ? "mic.fill" : "stop.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(activeTheme.accent, in: Circle())
            }
            .disabled(isGestureTestMode)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(activeTheme.surface, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func addDiagnostic(_ line: String) {
        diagnosticLogs.append(line)
        if diagnosticLogs.count > 300 {
            diagnosticLogs.removeFirst(diagnosticLogs.count - 300)
        }
    }

    private func handleLatestTranscript() {
        guard !isGestureTestMode else { return }
        guard let line = liveManager.lines.last, line.role == .assistant else { return }
        let text = line.text.lowercased()
        if text.contains("giải thích") || text.contains("explain") {
            guard !didTriggerExplainGesture else { return }
            didTriggerExplainGesture = true
            playExplainGesture()
        } else if text.contains("cảm ơn") || text.contains("thank") {
            guard !didTriggerContextGestureForTurn else { return }
            didTriggerContextGestureForTurn = true
            playAraEmpathy(reason: "assistant context")
        }
    }

    private func playExplainGesture() {
        explainGestureTask?.cancel()
        let generation = UUID()
        explainGestureGeneration = generation
        avatarClip = .talkExplain
        addDiagnostic("[ARA] TalkExplain triggered")
        explainGestureTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
            guard explainGestureGeneration == generation, avatarClip == .talkExplain else { return }
            avatarClip = liveManager.aiSpeaking ? .talk : (liveManager.state == .live ? .listening : .idle)
            explainGestureTask = nil
        }
    }

    private func cancelExplainGesture() {
        explainGestureGeneration = UUID()
        explainGestureTask?.cancel()
        explainGestureTask = nil
    }

    private func cancelEmotionGesture() {
        emotionGestureGeneration = UUID()
        emotionGestureTask?.cancel()
        emotionGestureTask = nil
    }
}
