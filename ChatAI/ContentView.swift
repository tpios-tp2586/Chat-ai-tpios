import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit


// MARK: - Shared chat UI tokens and credit

enum ChatDesignTokens {
    static let contentPadding: CGFloat = 14
    static let bubbleRadius: CGFloat = 14
    static let compactSpacing: CGFloat = 8
    static var userBubbleColor: Color { ChatAIThemeStore.current.accent.opacity(0.92) }
    static var assistantBubbleColor: Color { ChatAIThemeStore.current.surface }
}

struct ChatBrandingCredit: View {
    var compact: Bool = false

    var body: some View {
        Text("Design By Trương Phong")
            .font(compact ? .system(size: 9, weight: .regular) : .footnote)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .accessibilityLabel("Design By Trương Phong")
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showProviderMenu = false
    @State private var showCompanion = false
    @State private var showAttachmentMenu = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                        if viewModel.isSending {
                            HStack {
                                ProgressView()
                                Text("Đang trả lời...")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(ChatDesignTokens.contentPadding)
                }
                .onChange(of: viewModel.messages) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                HStack {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = error
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            if let voiceError = voiceManager.voiceErrorMessage {
                Text(voiceError)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            if voiceManager.isSpeaking {
                Button { voiceManager.stopSpeaking() } label: {
                    Label("Dừng đọc", systemImage: "stop.circle.fill")
                        .font(.footnote)
                }
                .padding(.horizontal)
            }

            inputBar
        }
        .background(activeTheme.background.ignoresSafeArea())
        .foregroundStyle(.primary)
        .tint(activeTheme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showCompanion) { CompanionChatView(viewModel: viewModel) }
        .sheet(isPresented: $showHistory) { HistoryView(viewModel: viewModel) }
        .confirmationDialog("Đính kèm", isPresented: $showAttachmentMenu, titleVisibility: .visible) {
            Button("Chọn ảnh") { showPhotoPicker = true }
            Button("Chọn tệp") { showFileImporter = true }
            Button("Hủy", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItems, maxSelectionCount: 6, matching: .images)
        .onChange(of: photoPickerItems) { items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    guard let rawData = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: rawData),
                          let normalized = image.jpegData(compressionQuality: 0.88) else {
                        viewModel.errorMessage = "Không đọc được một ảnh đã chọn."
                        continue
                    }
                    let attachment = ChatAttachment(name: "Ảnh \(viewModel.pendingAttachments.count + 1).jpg", mimeType: "image/jpeg", data: normalized)
                    viewModel.addPendingAttachment(attachment)
                }
                photoPickerItems = []
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .plainText, .pdf], allowsMultipleSelection: true) { result in
            do {
                for url in try result.get() {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let ext = url.pathExtension.lowercased()
                    if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) {
                        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.88) else {
                            viewModel.errorMessage = "Không đọc được ảnh: \(url.lastPathComponent)"
                            continue
                        }
                        viewModel.addPendingAttachment(ChatAttachment(name: url.lastPathComponent, mimeType: "image/jpeg", data: jpeg))
                    } else if ext == "pdf" {
                        let text = PDFDocument(data: data)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        guard !text.isEmpty else {
                            viewModel.errorMessage = "PDF không có văn bản trích xuất được: \(url.lastPathComponent)"
                            continue
                        }
                        viewModel.inputText += (viewModel.inputText.isEmpty ? "" : "\n\n") + "[Nội dung tệp \(url.lastPathComponent)]\n" + text
                    } else {
                        let text = String(data: data, encoding: .utf8) ?? ""
                        guard !text.isEmpty else {
                            viewModel.errorMessage = "Không đọc được tệp văn bản: \(url.lastPathComponent)"
                            continue
                        }
                        viewModel.inputText += (viewModel.inputText.isEmpty ? "" : "\n\n") + "[Nội dung tệp \(url.lastPathComponent)]\n" + text
                    }
                }
            } catch {
                viewModel.errorMessage = "Không mở được tệp: \(error.localizedDescription)"
            }
        }
        .onAppear {
            viewModel.onSpeakReply = { text, gender in
                let azureKey    = KeychainHelper.read(forKey: "azure_tts_key") ?? ""
                let azureRegion = KeychainHelper.read(forKey: "azure_tts_region") ?? ""
                voiceManager.speak(text: text, gender: gender, azureKey: azureKey, azureRegion: azureRegion)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(activeTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(activeTheme.accent.opacity(0.20), lineWidth: 1)
                        }
                }
                .accessibilityLabel("Lịch sử chat")

                Spacer(minLength: 2)

                VStack(spacing: 3) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(activeTheme.accent)
                            .frame(width: 7, height: 7)
                        Text("ChatAI")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .tracking(0.2)
                        Button { showProviderMenu = true } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.selectedProvider.rawValue
                                    .components(separatedBy: "(").first?
                                    .trimmingCharacters(in: .whitespaces) ?? "")
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(activeTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(activeTheme.accent.opacity(0.12), in: Capsule())
                        }
                        .confirmationDialog("Chọn AI", isPresented: $showProviderMenu, titleVisibility: .visible) {
                            ForEach(AIProviderKind.allCases) { provider in
                                Button(provider.rawValue) {
                                    viewModel.selectedProviderRaw = provider.rawValue
                                }
                            }
                            Button("Hủy", role: .cancel) {}
                        }
                    }
                    ChatBrandingCredit(compact: true)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 2)

                Button { showCompanion = true } label: {
                    Image(systemName: "person.crop.rectangle.stack")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(activeTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        }
                }
                .accessibilityLabel("Mở ChatAI 3D")
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(activeTheme.accent).frame(width: 6, height: 6)
                    Text("Sẵn sàng trò chuyện")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                LiveCallButton(viewModel: viewModel)
                Button { showSettings = true } label: {
                    Label("Cài đặt", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleAndIcon)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(activeTheme.accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(activeTheme.accent.opacity(0.10), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .background {
            activeTheme.background
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(activeTheme.accent.opacity(0.25))
                        .frame(height: 0.5)
                }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        ChatComposerSurface(accent: activeTheme.accent, surface: activeTheme.surface) {
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            HStack(spacing: 6) {
                                if let image = UIImage(data: attachment.data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 42, height: 42)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "doc.fill")
                                        .frame(width: 42, height: 42)
                                }
                                Button {
                                    viewModel.removePendingAttachment(id: attachment.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                            }
                            .padding(5)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            HStack(spacing: 9) {
                ChatActionButton(symbol: "plus", label: "Đính kèm ảnh hoặc tệp", accent: activeTheme.accent) {
                    showAttachmentMenu = true
                }
                ChatActionButton(
                    symbol: voiceManager.isListening ? "mic.fill" : "mic",
                    label: voiceManager.isListening ? "Dừng nghe" : "Nhập bằng giọng nói",
                    accent: voiceManager.isListening ? .red : activeTheme.accent
                ) {
                    let groqKey = KeychainHelper.read(forKey: AIProviderKind.groq.keychainKey) ?? ""
                    voiceManager.startListening(
                        groqAPIKey: groqKey,
                        onPartialResult: { viewModel.inputText = $0 },
                        onFinish: { text in
                            viewModel.inputText = text
                            viewModel.send()
                        }
                    )
                }
                ChatComposerField(text: $viewModel.inputText, accent: activeTheme.accent, placeholder: "Nhắn tin...")
                ChatActionButton(symbol: "paperplane.fill", label: "Gửi tin nhắn", accent: activeTheme.accent, prominent: true) {
                    viewModel.send()
                }
                .disabled((viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty) || viewModel.isSending)
            }
        }
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage
    @State private var copied = false
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if !message.attachments.isEmpty {
                    ForEach(message.attachments) { attachment in
                        if let image = UIImage(data: attachment.data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Label(attachment.name, systemImage: "doc.fill")
                                .font(.caption)
                        }
                    }
                }
                ChatMessageCard(
                    text: message.content,
                    isUser: message.role == .user,
                    accent: activeTheme.accent.opacity(0.92),
                    surface: activeTheme.surface
                )

                Button {
                    UIPasteboard.general.string = message.content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Đã copy" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

// MARK: - HistoryView

struct HistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }
    @StateObject private var historyManager = HistoryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showMemory = false
    @State private var renameSession: ChatSession?
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                if !historyManager.sessions.isEmpty {
                    Section("Cuộc hội thoại") {
                        ForEach(historyManager.sessions) { session in
                            Button {
                                viewModel.load(session: session)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(session.preview)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    Text(session.provider)
                                        .font(.caption2)
                                        .foregroundColor(activeTheme.accent)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    historyManager.delete(session: session)
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                                Button {
                                    renameSession = session
                                    newTitle = session.title
                                } label: {
                                    Label("Đổi tên", systemImage: "pencil")
                                }
                                .tint(activeTheme.accent)
                            }
                        }
                    }
                } else {
                    Text("Chưa có cuộc hội thoại nào.")
                        .foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(activeTheme.background)
            .listRowBackground(activeTheme.surface)
            .navigationTitle("Lịch sử chat")
            .tint(activeTheme.accent)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.startNewChat()
                        dismiss()
                    } label: {
                        Label("Chat mới", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showMemory = true } label: {
                            Image(systemName: "brain")
                        }
                        if !historyManager.sessions.isEmpty {
                            Button(role: .destructive) {
                                historyManager.deleteAll()
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showMemory) { MemoryView() }
            .alert("Đổi tên cuộc chat", isPresented: .init(
                get: { renameSession != nil },
                set: { if !$0 { renameSession = nil } }
            )) {
                TextField("Tên mới", text: $newTitle)
                Button("Lưu") {
                    if let session = renameSession {
                        historyManager.rename(session: session, newTitle: newTitle)
                    }
                    renameSession = nil
                }
                Button("Hủy", role: .cancel) { renameSession = nil }
            }
            .onAppear { historyManager.loadSessions() }
        }
    }
}

// MARK: - MemoryView

struct MemoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var activeTheme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }
    @Environment(\.dismiss) private var dismiss
    @State private var editingItem: MemoryItem?
    @State private var editingText = ""
    @State private var showMemoryEditor = false

    var body: some View {
        NavigationStack {
            List {
                if historyManager.memories.isEmpty {
                    Text("Chưa có thông tin nào được ghi nhớ. Anh có thể thêm thông tin bằng nút +.")
                        .font(.footnote).foregroundColor(.secondary).padding(.vertical, 8)
                } else {
                    ForEach(historyManager.memories) { item in
                        Button {
                            editingItem = item
                            editingText = item.content
                            showMemoryEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.content).foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.savedAt, style: .date).font(.caption2).foregroundColor(.secondary)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { historyManager.deleteMemory(item) } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                            Button {
                                editingItem = item
                                editingText = item.content
                                showMemoryEditor = true
                            } label: { Label("Sửa", systemImage: "pencil") }.tint(activeTheme.accent)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(activeTheme.background)
            .listRowBackground(activeTheme.surface)
            .navigationTitle("AI Memory")
            .tint(activeTheme.accent)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            editingItem = nil
                            editingText = ""
                            showMemoryEditor = true
                        } label: { Image(systemName: "plus") }
                        if !historyManager.memories.isEmpty {
                            Button(role: .destructive) { historyManager.clearAllMemory() } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) { Button("Đóng") { dismiss() } }
            }
            .alert(editingItem == nil ? "Thêm ghi nhớ" : "Chỉnh sửa ghi nhớ", isPresented: $showMemoryEditor) {
                TextField("Thông tin cần nhớ", text: $editingText)
                Button("Lưu") {
                    if let item = editingItem {
                        historyManager.updateMemory(item, content: editingText)
                    } else {
                        historyManager.addMemory(editingText)
                    }
                    editingItem = nil
                }
                Button("Hủy", role: .cancel) { editingItem = nil }
            }
            .onAppear { historyManager.loadMemory() }
        }
    }
}


 // MARK: - Premium chat presentation components

private enum ChatScreenStyle {
    static let cardRadius: CGFloat = 22
}

private struct ChatComposerSurface<Content: View>: View {
    let accent: Color
    let surface: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) { content }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: ChatScreenStyle.cardRadius, style: .continuous)
                    .fill(surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: ChatScreenStyle.cardRadius, style: .continuous)
                            .stroke(accent.opacity(0.20), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: -4)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}

private struct ChatComposerField: View {
    @Binding var text: String
    let accent: Color
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.system(size: 15))
            .lineLimit(1...5)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .tint(accent)
    }
}

private struct ChatActionButton: View {
    let symbol: String
    let label: String
    let accent: Color
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(prominent ? Color.white : accent)
                .frame(width: 42, height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            prominent
                            ? LinearGradient(
                                colors: [accent, accent.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [accent.opacity(0.16), accent.opacity(0.07)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accent.opacity(prominent ? 0.85 : 0.28), lineWidth: 1)
                        }
                }
                .shadow(color: accent.opacity(prominent ? 0.24 : 0.07), radius: prominent ? 9 : 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ChatMessageCard: View {
    let text: String
    let isUser: Bool
    let accent: Color
    let surface: Color

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .lineSpacing(4)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(isUser ? accent : surface)
                    .overlay {
                        if !isUser {
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .stroke(Color.white.opacity(0.055), lineWidth: 1)
                        }
                    }
            }
    }
}
