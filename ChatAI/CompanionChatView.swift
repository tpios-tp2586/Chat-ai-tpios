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
    @State private var showDiagnosticLog = false
    @State private var diagnosticLogs: [String] = ["[INFO] Mở màn hình Chat Voice"]

    var body: some View {
        ZStack {
            ChatAIThemeBackground(theme: activeTheme)

            VStack(spacing: 0) {
                header

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        ZStack {
                            AraAvatarView { log in
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
        .onChange(of: liveManager.lines.count) { _ in
            if let line = liveManager.lines.last {
                addDiagnostic("[VOICE] Có dòng thoại mới, vai trò: \(line.role)")
            }
            handleLatestTranscript()
        }
        .onChange(of: liveManager.lines.last?.text) { _ in
            handleLatestTranscript()
        }
        .onChange(of: liveManager.aiSpeaking) { speaking in
            addDiagnostic("[VOICE] AI đang nói: \(speaking)")
            if speaking {
                handleLatestTranscript()
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                if speaking {
                    // Speech is a mouth animation, not a facial emotion.
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