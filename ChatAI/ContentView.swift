import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit


// MARK: - Shared chat UI tokens and credit

enum ChatDesignTokens {
    static let contentPadding: CGFloat = 14
    static let bubbleRadius: CGFloat = 14
    static let compactSpacing: CGFloat = 8
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
                    .padding()
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
                    guard let rawData = try? await item.loadTransferable(type: Data.self) else { continue }
                    let normalized = UIImage(data: rawData)?.jpegData(compressionQuality: 0.88) ?? rawData
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
        ZStack {
            HStack {
                Button { showHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath").font(.title3)
                }
                .padding(.leading)
                Spacer()
                Button { showCompanion = true } label: {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.title3)
                }
                .accessibilityLabel("Mở ChatAI 3D")
                LiveCallButton(viewModel: viewModel)
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.title3)
                }
                .padding(.trailing)
            }

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        showProviderMenu = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedProvider.rawValue
                                .components(separatedBy: "(").first?
                                .trimmingCharacters(in: .whitespaces) ?? "")
                                .font(.headline)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
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
        }
        .padding(.vertical, 10)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 8) {
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
            HStack(spacing: 12) {
                Button { showAttachmentMenu = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .accessibilityLabel("Đính kèm ảnh hoặc tệp")

                Button {
                    let groqKey = KeychainHelper.read(forKey: AIProviderKind.groq.keychainKey) ?? ""
                    voiceManager.startListening(
                        groqAPIKey: groqKey,
                        onPartialResult: { viewModel.inputText = $0 },
                        onFinish: { text in
                            viewModel.inputText = text
                            viewModel.send()
                        }
                    )
                } label: {
                    Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                        .foregroundColor(voiceManager.isListening ? .red : .accentColor)
                }

                TextField("Nhắn tin...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button { viewModel.send() } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled((viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty) || viewModel.isSending)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage
    @State private var copied = false

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
                Text(message.content)
                    .padding(10)
                    .background(message.role == .user
                        ? Color.blue.opacity(0.85)
                        : Color(.secondarySystemBackground))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)

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
                                        .foregroundColor(.blue)
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
                                .tint(.orange)
                            }
                        }
                    }
                } else {
                    Text("Chưa có cuộc hội thoại nào.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Lịch sử chat")
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if historyManager.memories.isEmpty {
                    Text("Chưa có thông tin nào được ghi nhớ.\nAI sẽ tự động ghi nhớ thông tin quan trọng trong lúc chat.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(historyManager.memories) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.content)
                            Text(item.savedAt, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                historyManager.deleteMemory(item)
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Memory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !historyManager.memories.isEmpty {
                        Button(role: .destructive) {
                            historyManager.clearAllMemory()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}
