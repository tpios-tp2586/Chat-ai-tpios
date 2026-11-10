import Foundation

// MARK: - Chat Session (1 cuộc hội thoại)

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var provider: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "", provider: String, messages: [ChatMessage] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title.isEmpty ? ChatSession.defaultTitle() : title
        self.provider = provider
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    static func defaultTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return "Chat \(f.string(from: Date()))"
    }

    var preview: String {
        messages.last?.content.prefix(60).description ?? "Chưa có tin nhắn"
    }
}

// MARK: - Memory Item (thông tin AI ghi nhớ)

struct MemoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let savedAt: Date

    init(id: UUID = UUID(), content: String, savedAt: Date = Date()) {
        self.id = id
        self.content = content
        self.savedAt = savedAt
    }
}

// MARK: - HistoryManager

final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published var sessions: [ChatSession] = []
    @Published var memories: [MemoryItem] = []
    @Published var profileItems: [MemoryItem] = []

    private let docsDir: URL
    private let historyDir: URL
    private let memoryFile: URL
    private let profileFile: URL

    private init() {
        docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        historyDir = docsDir.appendingPathComponent("ChatHistory")
        memoryFile = docsDir.appendingPathComponent("memory.json")
        profileFile = docsDir.appendingPathComponent("profile.json")
        try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        loadSessions()
        loadMemory()
        loadProfile()
    }

    func loadSessions() {
        let files = (try? FileManager.default.contentsOfDirectory(at: historyDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        sessions = files.filter { $0.pathExtension == "json" }.compactMap { url -> ChatSession? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ChatSession.self, from: data)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(session: ChatSession) {
        var s = session
        s.updatedAt = Date()
        if let data = try? JSONEncoder().encode(s) {
            let url = historyDir.appendingPathComponent("\(s.id.uuidString).json")
            try? data.write(to: url)
        }
        loadSessions()
    }

    func delete(session: ChatSession) {
        let url = historyDir.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        loadSessions()
    }

    func rename(session: ChatSession, newTitle: String) {
        var s = session
        s.title = newTitle
        save(session: s)
    }

    func deleteAll() { sessions.forEach { delete(session: $0) } }

    func loadMemory() {
        guard let data = try? Data(contentsOf: memoryFile) else { return }
        memories = (try? JSONDecoder().decode([MemoryItem].self, from: data)) ?? []
    }

    func saveMemory() {
        if let data = try? JSONEncoder().encode(memories) { try? data.write(to: memoryFile) }
    }

    func addMemory(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        guard !trimmed.isEmpty,
              memories.count < 50,
              !memories.contains(where: {
                  $0.content.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased() == normalized
              }) else { return }
        memories.append(MemoryItem(content: trimmed))
        saveMemory()
    }

    func updateMemory(_ item: MemoryItem, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = memories.firstIndex(where: { $0.id == item.id }) else { return }
        memories[index].content = trimmed
        saveMemory()
    }

    func deleteMemory(_ item: MemoryItem) {
        memories.removeAll { $0.id == item.id }
        saveMemory()
    }

    func clearAllMemory() {
        memories.removeAll()
        saveMemory()
    }

    func loadProfile() {
        guard let data = try? Data(contentsOf: profileFile) else { return }
        profileItems = (try? JSONDecoder().decode([MemoryItem].self, from: data)) ?? []
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profileItems) { try? data.write(to: profileFile) }
    }

    func addProfile(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        guard !trimmed.isEmpty, profileItems.count < 50,
              !profileItems.contains(where: { $0.content.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased() == normalized }) else { return }
        profileItems.append(MemoryItem(content: trimmed))
        saveProfile()
    }

    func updateProfile(_ item: MemoryItem, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = profileItems.firstIndex(where: { $0.id == item.id }) else { return }
        profileItems[index].content = trimmed
        saveProfile()
    }

    func deleteProfile(_ item: MemoryItem) {
        profileItems.removeAll { $0.id == item.id }
        saveProfile()
    }

    var profileSystemPrompt: String? {
        guard !profileItems.isEmpty else { return nil }
        let items = profileItems.suffix(20).map { "- \($0.content)" }.joined(separator: "\n")
        return """
        Hồ sơ dài hạn của người dùng (chỉ dùng ngầm khi thực sự liên quan):
        \(String(items.prefix(3000)))
        Không tự nhắc, không kể lại, không khoe rằng bạn biết các thông tin này. Chỉ đề cập khi người dùng hỏi hoặc khi thông tin trực tiếp cần thiết để trả lời chính xác.
        """
    }

    var memorySystemPrompt: String? {
        guard !memories.isEmpty else { return nil }
        let items = memories.suffix(15).map { "- \($0.content)" }.joined(separator: "\n")
        let limitedItems = String(items.prefix(3000))
        return "Thông tin tham khảo từ các cuộc trò chuyện trước:\n\(limitedItems)\n\nChỉ dùng khi thực sự liên quan; không tự nhắc lại hoặc đưa ra nếu người dùng không hỏi."
    }

    static func extractMemoryPrompt(from message: String) -> String {
        return """
        Đọc tin nhắn sau và phân loại thông tin dài hạn.
        - PROFILE: thông tin hồ sơ ổn định như cách xưng hô, công việc, dự án lâu dài, sở thích bền vững, mục tiêu.
        - MEMORY: chi tiết hữu ích của hội thoại không thuộc hồ sơ cá nhân.
        Chỉ lưu điều người dùng nói rõ, không suy đoán.
        Trả về từng dòng theo đúng tiền tố PROFILE: hoặc MEMORY:. Nếu không có gì đáng lưu, trả về NONE. Không giải thích thêm.

        Tin nhắn: "\(message)"
        """
    }
}
