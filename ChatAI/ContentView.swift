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
    @State private var showMemory = false
    @State private var showProviderMenu = false
    @State private var showCompanion = false
    @State private var showAttachmentMenu = false
    @State private var showMoreAttachmentOptions = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
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
            if showAttachmentMenu {
                attachmentQuickActions
            }
            bottomNavigation
        }
        .background(activeTheme.background.ignoresSafeArea())
        .foregroundStyle(.primary)
        .tint(activeTheme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showCompanion) { CompanionChatView(viewModel: viewModel) }
        .sheet(isPresented: $showHistory) { HistoryView(viewModel: viewModel) }
        .sheet(isPresented: $showMemory) { MemoryView() }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                guard let data = image.jpegData(compressionQuality: 0.88) else {
                    viewModel.errorMessage = "Không lưu được ảnh chụp."
                    return
                }
                viewModel.addPendingAttachment(ChatAttachment(name: "Ảnh chụp.jpg", mimeType: "image/jpeg", data: data))
            }
        }
        .confirmationDialog("Thêm tệp đính kèm", isPresented: $showMoreAttachmentOptions, titleVisibility: .visible) {
            Button("Chọn ảnh") { showPhotoPicker = true }
            Button("Chọn tệp") { showFileImporter = true }
            Button("Đóng", role: .cancel) {}
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
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(
                            colors: [activeTheme.accent.opacity(0.28), activeTheme.accent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    ChatAICustomIcon(kind: .companion, color: activeTheme.accent, theme: activeTheme)
                        .frame(width: 23, height: 23)
                }
                .frame(width: 42, height: 42)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(activeTheme.accent.opacity(0.42), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("ChatAI")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Button { showProviderMenu = true } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedProvider.rawValue
                                .components(separatedBy: "(").first?
                                .trimmingCharacters(in: .whitespaces) ?? "")
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(activeTheme.accent)
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
            }

            Spacer(minLength: 4)

            LiveCallButton(viewModel: viewModel)

            Button { showCompanion = true } label: {
                ChatAICustomIcon(kind: .companion, color: activeTheme.accent, theme: activeTheme)
                    .frame(width: 20, height: 20)
                    .frame(width: 40, height: 40)
                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(activeTheme.accent.opacity(0.25), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Mở ChatAI 3D")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(activeTheme.background)
    }

    // MARK: - Bottom navigation

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            bottomNavigationItem(title: "Chat", kind: .companion, selected: true) {
                // Already on the Chat tab; preserve the current conversation.
            }
            bottomNavigationItem(title: "Lịch sử", kind: .history) {
                showHistory = true
            }
            bottomNavigationItem(title: "Memory", kind: .memory) {
                showMemory = true
            }
            bottomNavigationItem(title: "Cài đặt", kind: .settings) {
                showSettings = true
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            activeTheme.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(activeTheme.accent.opacity(0.22))
                        .frame(height: 0.7)
                }
        }
    }

    private func bottomNavigationItem(
        title: String,
        kind: ChatAIIconKind,
        selected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ChatAICustomIcon(
                    kind: kind,
                    color: selected ? activeTheme.accent : .secondary,
                    theme: activeTheme
                )
                .frame(width: 21, height: 21)
                Text(title)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? activeTheme.accent : Color.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Attachment quick actions

    private var attachmentQuickActions: some View {
        HStack(spacing: 0) {
            attachmentQuickAction(title: "Tệp", symbol: "doc", color: activeTheme.accent) {
                showAttachmentMenu = false
                showFileImporter = true
            }
            attachmentQuickAction(title: "Hình ảnh", symbol: "photo", color: activeTheme.accent) {
                showAttachmentMenu = false
                showPhotoPicker = true
            }
            attachmentQuickAction(title: "Giọng nói", symbol: "mic", color: activeTheme.accent) {
                showAttachmentMenu = false
                startVoiceInput()
            }
            attachmentQuickAction(title: "Chụp ảnh", symbol: "camera", color: activeTheme.accent) {
                showAttachmentMenu = false
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    viewModel.errorMessage = "Camera không khả dụng trên thiết bị này."
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(activeTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(activeTheme.accent.opacity(0.18)).frame(height: 0.7)
        }
    }

    private func attachmentQuickAction(
        title: String,
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func startVoiceInput() {
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
                ChatActionButton(kind: .attachment, label: "Mở lựa chọn đính kèm", accent: activeTheme.accent) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showAttachmentMenu.toggle()
                    }
                }
                ChatComposerField(text: $viewModel.inputText, accent: activeTheme.accent, placeholder: "Nhắn tin...")
                ChatActionButton(kind: .send, label: "Gửi tin nhắn", accent: activeTheme.accent, prominent: true) {
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
    @State private var searchText = ""
    @State private var selectedFilter = "Tất cả"

    private let filters = ["Tất cả", "Văn bản", "Giọng nói", "Hình ảnh"]

    private var filteredSessions: [ChatSession] {
        historyManager.sessions.filter { session in
            let matchesSearch = searchText.isEmpty ||
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.preview.localizedCaseInsensitiveContains(searchText) ||
                session.provider.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch selectedFilter {
            case "Giọng nói":
                matchesFilter = session.title.localizedCaseInsensitiveContains("voice") ||
                    session.preview.localizedCaseInsensitiveContains("giọng nói")
            case "Hình ảnh":
                matchesFilter = session.preview.localizedCaseInsensitiveContains("ảnh") ||
                    session.preview.localizedCaseInsensitiveContains("image")
            case "Văn bản":
                matchesFilter = true
            default:
                matchesFilter = true
            }
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(activeTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(activeTheme.surface, in: Circle())
                    }
                    Text("Lịch sử chat")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        viewModel.startNewChat()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(activeTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if !historyManager.sessions.isEmpty {
                        Button(role: .destructive) {
                            historyManager.deleteAll()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(activeTheme.accent)
                                .frame(width: 36, height: 36)
                                .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Tìm kiếm...", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 13)
                .frame(height: 42)
                .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(activeTheme.accent.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            Button { selectedFilter = filter } label: {
                                Text(filter)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selectedFilter == filter ? Color.white : Color.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background {
                                        Capsule().fill(selectedFilter == filter ? activeTheme.accent : activeTheme.surface)
                                    }
                                    .overlay(Capsule().stroke(activeTheme.accent.opacity(selectedFilter == filter ? 0.8 : 0.18), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        if filteredSessions.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30))
                                    .foregroundStyle(activeTheme.accent)
                                Text(searchText.isEmpty ? "Chưa có cuộc hội thoại nào" : "Không tìm thấy cuộc hội thoại")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(searchText.isEmpty ? "Các cuộc trò chuyện của anh sẽ xuất hiện ở đây." : "Thử từ khóa khác nhé.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 44)
                            .padding(.horizontal, 20)
                            .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        } else {
                            ForEach(filteredSessions) { session in
                                Button {
                                    viewModel.load(session: session)
                                    dismiss()
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 13)
                                                .fill(activeTheme.accent.opacity(0.14))
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(activeTheme.accent)
                                        }
                                        .frame(width: 44, height: 44)

                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                                Text(session.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Spacer(minLength: 4)
                                                Text(session.preview.isEmpty ? "" : session.provider)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(activeTheme.accent)
                                                    .lineLimit(1)
                                            }
                                            Text(session.preview)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            HStack {
                                                Text(session.provider)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(activeTheme.accent)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 17))
                                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(activeTheme.accent.opacity(0.17), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        renameSession = session
                                        newTitle = session.title
                                    } label: {
                                        Label("Đổi tên", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        historyManager.delete(session: session)
                                    } label: {
                                        Label("Xóa", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }

                HStack(spacing: 0) {
                    historyBottomItem("Chat", symbol: "bubble.left.and.bubble.right") { dismiss() }
                    historyBottomItem("Lịch sử", symbol: "clock.arrow.circlepath", selected: true) {}
                    historyBottomItem("Memory", symbol: "brain") { showMemory = true }
                    historyBottomItem("Cài đặt", symbol: "gearshape") {}
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(activeTheme.background.overlay(alignment: .top) {
                    Rectangle().fill(activeTheme.accent.opacity(0.22)).frame(height: 0.7)
                })
            }
            .background(activeTheme.background.ignoresSafeArea())
            .foregroundStyle(.primary)
            .tint(activeTheme.accent)
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showMemory) { MemoryView() }
            .sheet(isPresented: Binding(
                get: { renameSession != nil },
                set: { if !$0 { renameSession = nil } }
            )) {
                NavigationStack {
                    Form {
                        TextField("Tên mới", text: $newTitle)
                            .foregroundStyle(Color.primary)
                    }
                    .scrollContentBackground(.hidden)
                    .background(activeTheme.background)
                    .navigationTitle("Đổi tên cuộc chat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Hủy") { renameSession = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                if let session = renameSession {
                                    historyManager.rename(session: session, newTitle: newTitle)
                                }
                                renameSession = nil
                            }
                        }
                    }
                    .preferredColorScheme(.dark)
                }
                .presentationDetents([.medium])
            }
            .onAppear { historyManager.loadSessions() }
        }
    }

    private func historyBottomItem(_ title: String, symbol: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? activeTheme.accent : Color.secondary)
                Text(title)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? activeTheme.accent : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MemoryView

struct MemoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var editingItem: MemoryItem?
    @State private var editingText = ""
    @State private var showMemoryEditor = false
    @State private var searchText = ""
    @State private var showClearConfirmation = false
    @State private var selectedProfileField: String?

    private var activeTheme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }
    private var filteredMemories: [MemoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return historyManager.memories.sorted { $0.savedAt > $1.savedAt } }
        return historyManager.memories.filter { $0.content.localizedCaseInsensitiveContains(query) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileSections
                    searchField
                    if historyManager.memories.count >= 50 {
                        Label("Bộ nhớ đã đạt giới hạn 50 mục. Xóa một mục cũ trước khi thêm mới.", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(activeTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(11)
                            .background(activeTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GHI NHỚ CỦA ANH")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(activeTheme.accent)
                            Text("\(filteredMemories.count) mục thông tin")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            beginAdd()
                        } label: {
                            Label("Thêm mới", systemImage: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(activeTheme.accent.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(activeTheme.accent.opacity(0.45), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(historyManager.memories.count >= 50)
                        .opacity(historyManager.memories.count >= 50 ? 0.45 : 1)
                    }

                    if filteredMemories.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: searchText.isEmpty ? "brain.head.profile" : "magnifyingglass")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(activeTheme.accent)
                            Text(searchText.isEmpty ? "Chưa có ghi nhớ nào" : "Không tìm thấy kết quả")
                                .font(.system(size: 16, weight: .semibold))
                            Text(searchText.isEmpty
                                 ? "Thêm thông tin quan trọng để ChatAI tham khảo trong những cuộc trò chuyện sau."
                                 : "Thử từ khóa khác hoặc xóa nội dung tìm kiếm.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            if searchText.isEmpty {
                                Button("Tạo ghi nhớ đầu tiên") { beginAdd() }
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 15).padding(.vertical, 10)
                                    .background(activeTheme.accent, in: Capsule())
                                    .foregroundStyle(Color.black)
                                    .disabled(historyManager.memories.count >= 50)
                                    .opacity(historyManager.memories.count >= 50 ? 0.45 : 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                        .padding(.horizontal, 18)
                        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(activeTheme.accent.opacity(0.16), lineWidth: 1))
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredMemories) { item in
                                memoryCard(item)
                            }
                        }
                    }

                    Text("Ghi nhớ được lưu trên thiết bị và được đưa vào ngữ cảnh AI khi phù hợp.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            HStack(spacing: 0) {
                bottomItem("Chat", symbol: "bubble.left.and.bubble.right") { dismiss() }
                bottomItem("Lịch sử", symbol: "clock.arrow.circlepath") { dismiss() }
                bottomItem("Memory", symbol: "brain", selected: true) {}
                bottomItem("Cài đặt", symbol: "gearshape") { dismiss() }
            }
            .padding(.top, 9)
            .padding(.bottom, 4)
            .background(activeTheme.background.overlay(alignment: .top) {
                Rectangle().fill(activeTheme.accent.opacity(0.24)).frame(height: 0.7)
            })
        }
        .background(activeTheme.background.ignoresSafeArea())
        .foregroundStyle(.primary)
        .tint(activeTheme.accent)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMemoryEditor, onDismiss: { editingItem = nil }) {
            editorSheet
        }
        .confirmationDialog("Xóa toàn bộ ghi nhớ?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Xóa tất cả", role: .destructive) { historyManager.clearAllMemory() }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Thao tác này không thể hoàn tác.")
        }
        .onAppear { historyManager.loadMemory() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(activeTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text("AI MEMORY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(activeTheme.accent)
                Text("Trí nhớ của ChatAI")
                    .font(.system(size: 19, weight: .bold))
            }
            Spacer()
            Button { beginAdd() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(activeTheme.accent, in: Circle())
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .disabled(historyManager.memories.count >= 50)
            .opacity(historyManager.memories.count >= 50 ? 0.45 : 1)
            if !historyManager.memories.isEmpty {
                Button { showClearConfirmation = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(activeTheme.surface, in: Circle())
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(activeTheme.background)
    }

    private var overviewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(activeTheme.accent.opacity(0.14))
                    .frame(width: 58, height: 58)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(activeTheme.accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Bộ nhớ cá nhân")
                    .font(.system(size: 16, weight: .bold))
                Text("Lưu sở thích, thông tin và cách anh muốn ChatAI hỗ trợ.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(historyManager.memories.count) / 50 ghi nhớ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(activeTheme.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(activeTheme.accent.opacity(0.28), lineWidth: 1))
    }

    private let profileFields: [(title: String, icon: String, hint: String)] = [
        ("Tên của bạn", "person.fill", "Tên anh muốn ChatAI gọi"),
        ("Công việc / dự án", "briefcase.fill", "Công việc, dự án đang làm"),
        ("Sở thích", "heart.fill", "Những điều anh yêu thích"),
        ("Mục tiêu", "target", "Mục tiêu cá nhân hoặc công việc"),
        ("Cách xưng hô", "bubble.left.and.bubble.right.fill", "Ví dụ: anh – em"),
        ("Yêu cầu đặc biệt", "star.fill", "Cách trả lời hoặc lưu ý riêng")
    ]

    private var profileSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HỒ SƠ CỦA ANH")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(activeTheme.accent)
                Spacer()
                Text("TÙY CHỈNH")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            ForEach(profileFields, id: \.title) { field in
                let matching = historyManager.memories.filter {
                    $0.content.lowercased().hasPrefix((field.title + ":").lowercased())
                }.sorted { $0.savedAt > $1.savedAt }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: field.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(activeTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(activeTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(field.title).font(.system(size: 14, weight: .semibold))
                            Text(matching.first.map { String($0.content.dropFirst(field.title.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines) } ?? field.hint)
                                .font(.system(size: 12))
                                .foregroundStyle(matching.isEmpty ? Color.secondary : Color.primary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        Button {
                            editingItem = matching.first
                            editingText = matching.first.map { String($0.content.dropFirst(field.title.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                            showMemoryEditor = true
                            selectedProfileField = field.title
                        } label: {
                            Image(systemName: matching.isEmpty ? "plus" : "pencil")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(activeTheme.accent)
                                .frame(width: 30, height: 30)
                                .background(activeTheme.accent.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(historyManager.memories.count >= 50 && matching.isEmpty)
                    }
                }
                .padding(12)
                .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(activeTheme.accent.opacity(0.14), lineWidth: 1))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Tìm trong ghi nhớ...", text: $searchText)
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 12)
        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(activeTheme.accent.opacity(0.14), lineWidth: 1))
    }

    private func memoryCard(_ item: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(activeTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                Text(item.content)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 10))
                Text(item.savedAt, style: .date).font(.system(size: 10))
                Text("•")
                Text(item.savedAt, style: .time).font(.system(size: 10))
                Spacer()
                Button { beginEdit(item) } label: {
                    Label("Sửa", systemImage: "pencil")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                Button(role: .destructive) { historyManager.deleteMemory(item) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.leading, 5)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(activeTheme.accent.opacity(0.14), lineWidth: 1))
        .contextMenu {
            Button { beginEdit(item) } label: { Label("Sửa ghi nhớ", systemImage: "pencil") }
            Button(role: .destructive) { historyManager.deleteMemory(item) } label: { Label("Xóa ghi nhớ", systemImage: "trash") }
        }
    }

    private var editorSheet: some View {
        NavigationStack {
            Form {
                Section("Nội dung") {
                    TextField(selectedProfileField.map { "Nhập nội dung cho: " + $0 } ?? "Ví dụ: Ưu tiên trả lời bằng tiếng Việt...", text: $editingText, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section {
                    Text("Thông tin này sẽ được lưu vào bộ nhớ của ChatAI để tham khảo ở các cuộc trò chuyện phù hợp.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(activeTheme.background)
            .navigationTitle(editingItem == nil ? "Thêm ghi nhớ" : "Sửa ghi nhớ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { showMemoryEditor = false; editingItem = nil; selectedProfileField = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { saveEditor() }
                        .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.medium, .large])
    }

    private func beginAdd() {
        editingItem = nil
        selectedProfileField = nil
        editingText = ""
        showMemoryEditor = true
    }

    private func beginEdit(_ item: MemoryItem) {
        editingItem = item
        editingText = item.content
        showMemoryEditor = true
    }

    private func saveEditor() {
        let value = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let storedValue = selectedProfileField.map { "\($0): \(value)" } ?? value
        if let item = editingItem {
            historyManager.updateMemory(item, content: storedValue)
        } else {
            historyManager.addMemory(storedValue)
        }
        showMemoryEditor = false
        editingItem = nil
        selectedProfileField = nil
    }

    private func bottomItem(_ title: String, symbol: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? activeTheme.accent : Color.secondary)
                Text(title)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? activeTheme.accent : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    let kind: ChatAIIconKind
    let label: String
    let accent: Color
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChatAICustomIcon(kind: kind, color: prominent ? .white : accent, theme: ChatAIThemeStore.current)
                .frame(width: 20, height: 20)
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


// MARK: - Custom compact icon set
enum ChatAIIconKind {
    case history, companion, settings, attachment, microphone, send, voice, memory, provider
}

struct ChatAICustomIcon: View {
    let kind: ChatAIIconKind
    let color: Color
    var theme: ChatAITheme = ChatAIThemeStore.current

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let u = s / 24
            // Preserve icon geometry and button dimensions while adapting line weight to theme.
            let strokeWeight: CGFloat = {
                switch theme {
                case .firePremium: return 1.9
                case .sunrise: return 1.8
                case .nature: return 1.75
                case .minimal: return 1.45
                }
            }()
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            func line(_ points: [CGPoint], width: CGFloat? = nil) {
                guard let first = points.first else { return }
                var path = Path()
                path.move(to: p(first.x, first.y))
                for point in points.dropFirst() { path.addLine(to: p(point.x, point.y)) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: (width ?? strokeWeight) * u, lineCap: .round, lineJoin: .round))
            }
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fill: Bool = true) {
                let rect = CGRect(x: (x-r)*u, y: (y-r)*u, width: 2*r*u, height: 2*r*u)
                context.drawLayer { layer in
                    if fill { layer.fill(Path(ellipseIn: rect), with: .color(color)) }
                    else { layer.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: strokeWeight*u) }
                }
            }
            switch kind {
            case .history:
                var arc = Path()
                arc.addArc(center: p(12,12), radius: 8*u, startAngle: .degrees(-55), endAngle: .degrees(250), clockwise: false)
                context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: strokeWeight*u))
                line([CGPoint(x:4,y:4),CGPoint(x:4,y:9),CGPoint(x:9,y:9)])
                line([CGPoint(x:12,y:7),CGPoint(x:12,y:12),CGPoint(x:16,y:14)])
            case .companion:
                circle(12,4,1.5); line([CGPoint(x:12,y:5.5),CGPoint(x:12,y:7)])
                var face = Path(roundedRect: CGRect(x:4*u,y:7*u,width:16*u,height:13*u), cornerSize: CGSize(width:4*u,height:4*u))
                context.stroke(face, with: .color(color), lineWidth: 1.7*u)
                circle(9,12,1.2); circle(15,12,1.2); line([CGPoint(x:9,y:16),CGPoint(x:15,y:16)])
            case .settings:
                for (x,y) in [(5,9),(12,15),(19,7)] {
                    line([CGPoint(x:CGFloat(x),y:3),CGPoint(x:CGFloat(x),y:21)])
                    circle(CGFloat(x),CGFloat(y),2.1)
                }
            case .attachment:
                line([CGPoint(x:12,y:4),CGPoint(x:12,y:20)])
                line([CGPoint(x:4,y:12),CGPoint(x:20,y:12)])
            case .microphone:
                let capsule = Path(roundedRect: CGRect(x:9*u,y:3*u,width:6*u,height:12*u), cornerSize: CGSize(width:3*u,height:3*u))
                context.stroke(capsule, with: .color(color), lineWidth: 1.8*u)
                line([CGPoint(x:5,y:11),CGPoint(x:5,y:13),CGPoint(x:7,y:17),CGPoint(x:12,y:19),CGPoint(x:17,y:17),CGPoint(x:19,y:13),CGPoint(x:19,y:11)])
                line([CGPoint(x:12,y:19),CGPoint(x:12,y:22)]); line([CGPoint(x:8,y:22),CGPoint(x:16,y:22)])
            case .send:
                line([CGPoint(x:3,y:11),CGPoint(x:21,y:3),CGPoint(x:15,y:21),CGPoint(x:11,y:13),CGPoint(x:3,y:11)])
                line([CGPoint(x:11,y:13),CGPoint(x:21,y:3)])
            case .voice:
                for (i,h) in [7,12,18,10,15,8].enumerated() {
                    let rect = CGRect(x: CGFloat(4+i*3)*u, y: (12-CGFloat(h)/2)*u, width: 2*u, height: CGFloat(h)*u)
                    context.fill(Path(roundedRect: rect, cornerSize: CGSize(width:u,height:u)), with: .color(color))
                }
            case .memory:
                line([CGPoint(x:12,y:3),CGPoint(x:12,y:21)])
                line([CGPoint(x:12,y:7),CGPoint(x:7,y:7),CGPoint(x:7,y:11)])
                line([CGPoint(x:12,y:15),CGPoint(x:17,y:15),CGPoint(x:17,y:19)])
                circle(12,3,1.5); circle(7,11,1.5); circle(17,19,1.5)
            case .provider:
                line([CGPoint(x:12,y:12),CGPoint(x:5,y:5)])
                line([CGPoint(x:12,y:12),CGPoint(x:19,y:5)])
                line([CGPoint(x:12,y:12),CGPoint(x:12,y:21)])
                circle(5,5,2); circle(19,5,2); circle(12,12,2); circle(12,21,2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}


private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
