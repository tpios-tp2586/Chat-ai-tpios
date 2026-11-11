import UIKit
import SwiftUI

struct CompanionChatView: View {
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
    @State private var greetingRequest = 0
    @State private var speechGestureRequest = 0
    @State private var lastGestureSentence = ""
    @State private var message: String?
    @State private var typedMessage = ""
    @State private var showDiagnosticLog = false
    @State private var diagnosticLogs: [String] = ["[INFO] Mở màn hình Chat Voice"]
    @State private var selectedDiagnosticText = ""


    var body: some View {
        ZStack {
            ChatAIThemeBackground(theme: activeTheme)

            VStack(spacing: 0) {
                header

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        ZStack {
                            AlinaAvatarView(isSpeaking: liveManager.aiSpeaking, greetingRequest: greetingRequest, speechGestureRequest: speechGestureRequest, onLog: { log in
                                addDiagnostic(log)
                            }, onTap: {
                                toggleConversation()
                            })

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
                addDiagnostic("[VOICE] Có dòng thoại mới, vai trò: \(line.role)")
            }
            handleLatestTranscript()
        }
        .onChange(of: liveManager.lines.last?.text) { _ in
            handleLatestTranscript()
            updateSpeechGestureRequest()
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            addDiagnostic("[VOICE] AI đang nói: \(speaking)")
            if !speaking {
                lastGestureSentence = ""
            }
            if speaking {
                handleLatestTranscript()
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                if speaking {
                    // Speech updates this status label only; Alina is currently displayed without facial animation.
                    if emotion == .idle || emotion == .listening || emotion == .thinking {
                        emotion = .speaking
                    }
                } else if emotion == .speaking {
                    switch liveManager.state {
                    case .idle: emotion = .idle
                    case .connecting: emotion = .thinking
                    case .live: emotion = .listening
                    }
                }
            }
        }
        .onChange(of: liveManager.state) { state in
            addDiagnostic("[VOICE] Trạng thái: \(String(describing: state))")
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
                Text("Gemini Live")
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

        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var diagnosticLogText: String {
        diagnosticLogs.joined(separator: "\n")
    }

    private var diagnosticLogSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Log chẩn đoán Chat Voice").font(.headline)
                Text("Chỉ giữ log cần cho kiểm tra rig Alina và lỗi tải model. Nội dung hiển thị và sao chép dùng chung một nguồn.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    SelectableDiagnosticText(text: diagnosticLogText, selectedText: $selectedDiagnosticText)
                        .padding(12)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = diagnosticLogText
                    } label: {
                        Label("Copy tất cả", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        UIPasteboard.general.string = selectedDiagnosticText
                    } label: {
                        Label("Copy đoạn chọn", systemImage: "text.quote")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedDiagnosticText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(role: .destructive) {
                        diagnosticLogs.removeAll()
                        selectedDiagnosticText = ""
                    } label: {
                        Label("Xóa", systemImage: "trash")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }.padding()
                .navigationTitle("Log Chat Voice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { showDiagnosticLog = false }
                } }
        }
    }

    private func handleLatestTranscript() {
        guard let line = liveManager.lines.last else { return }
        message = line.text
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            emotion = line.role == .user ? .listening : emotionForAssistantText(line.text)
        }
    }

    private func updateSpeechGestureRequest() {
        guard liveManager.aiSpeaking,
              let line = liveManager.lines.last,
              line.role == .assistant,
              let boundary = line.text.lastIndex(where: { ".!?。！？\n".contains($0) }) else {
            return
        }

        let completedSentence = String(line.text[...boundary])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !completedSentence.isEmpty,
              completedSentence != lastGestureSentence else {
            return
        }

        lastGestureSentence = completedSentence
        speechGestureRequest += 1
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
        let isRequiredLog = line.hasPrefix("[ALINA RIG AUDIT]") ||
            line.hasPrefix("[ALINA ERROR]") ||
            line.hasPrefix("[INFO]")
        guard isRequiredLog else { return }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        diagnosticLogs.append("[\(timestamp)] \(line)")
    }

    private var controls: some View {
        HStack(spacing: 10) {
            TextField("Nhập tin nhắn cho Alina…", text: $typedMessage, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(activeTheme.accent.opacity(0.24), lineWidth: 1)
                }
                .submitLabel(.send)
                .onSubmit(sendTypedMessage)

            Button(action: sendTypedMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(activeTheme.accent, in: Circle())
            }
            .disabled(typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(activeTheme.background.opacity(0.96))
    }

    private func sendTypedMessage() {
        let text = typedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard liveManager.sendText(text) else {
            message = liveManager.state == .connecting
                ? "Gemini Live đang kết nối, anh chờ một chút nhé."
                : "Anh chạm vào Alina để kết nối Gemini Live trước nhé."
            addDiagnostic("[TEXT] Chưa gửi: Gemini Live chưa ở trạng thái kết nối")
            return
        }
        typedMessage = ""
        message = text
        addDiagnostic("[TEXT] Đã gửi văn bản trực tiếp vào phiên Gemini Live")
    }

    private func toggleConversation() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if liveManager.state == .idle {
            greetingRequest += 1
            addDiagnostic("[VOICE] Avatar tapped: starting voice conversation")
            startLive()
        } else {
            addDiagnostic("[VOICE] Avatar tapped: ending voice conversation")
            liveManager.end()
        }
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


private enum CompanionEmotion {
    case idle, listening, thinking, speaking, happy, surprised, confused, sad, angry, sleepy

}

private struct SelectableDiagnosticText: UIViewRepresentable {
    let text: String
    @Binding var selectedText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedText: $selectedText)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = UIFont.monospacedSystemFont(ofSize: UIFont.smallSystemFontSize, weight: .regular)
        view.text = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
            selectedText = ""
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var selectedText: String

        init(selectedText: Binding<String>) {
            _selectedText = selectedText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            guard range.location != NSNotFound, range.length > 0,
                  let selectedRange = Range(range, in: textView.text) else {
                selectedText = ""
                return
            }
            selectedText = String(textView.text[selectedRange])
        }
    }
}
