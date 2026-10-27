import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var pendingAttachments: [ChatAttachment] = []
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    @Published var currentSession: ChatSession?
    @Published var isExtractingMemory: Bool = false

    @AppStorage("selectedProvider") var selectedProviderRaw: String = AIProviderKind.openAI.rawValue
    @AppStorage("model_openai")    var openAIModel:    String = AIProviderKind.openAI.defaultModel
    @AppStorage("model_anthropic") var anthropicModel: String = AIProviderKind.anthropic.defaultModel
    @AppStorage("model_gemini")    var geminiModel:    String = AIProviderKind.gemini.defaultModel
    @AppStorage("model_grok")      var grokModel:      String = AIProviderKind.grok.defaultModel
    @AppStorage("model_deepseek")  var deepseekModel:  String = AIProviderKind.deepseek.defaultModel
    @AppStorage("model_groq")      var groqModel:      String = AIProviderKind.groq.defaultModel
    @AppStorage("autoSpeakReplies") var autoSpeakReplies: Bool = false
    @AppStorage("voiceGender")     var voiceGenderRaw: String = VoiceGender.female.rawValue
    @AppStorage("autoMemoryV2")    var autoMemory: Bool = false

    var voiceGender: VoiceGender { VoiceGender(rawValue: voiceGenderRaw) ?? .female }
    var onSpeakReply: ((String, VoiceGender) -> Void)?
    var selectedProvider: AIProviderKind { AIProviderKind(rawValue: selectedProviderRaw) ?? .openAI }

    private var currentModel: String {
        switch selectedProvider {
        case .openAI:    return openAIModel
        case .anthropic: return anthropicModel
        case .gemini:    return geminiModel
        case .grok:      return grokModel
        case .deepseek:  return deepseekModel
        case .groq:      return groqModel
        }
    }

    private let openAIService   = OpenAICompatibleService(baseURL: URL(string: "https://api.openai.com/v1/chat/completions")!)
    private let grokService     = OpenAICompatibleService(baseURL: URL(string: "https://api.x.ai/v1/chat/completions")!)
    private let deepseekService = OpenAICompatibleService(baseURL: URL(string: "https://api.deepseek.com/chat/completions")!)
    private let groqService     = OpenAICompatibleService(baseURL: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
    private let anthropicService = AnthropicService()
    private let geminiService    = GeminiService()

    // Mỗi câu nói đã được xử lý một lần trong phiên voice, tránh gọi API Memory lặp lại.
    private var extractedVoiceMemoryKeys = Set<String>()

    func startNewChat() {
        saveCurrentSession()
        pendingAttachments = []
        messages = []
        errorMessage = nil
        currentSession = nil
    }

    func load(session: ChatSession) {
        saveCurrentSession()
        pendingAttachments = []
        messages = session.messages
        currentSession = session
        errorMessage = nil
    }

    func saveCurrentSession(provider: String? = nil) {
        guard !messages.isEmpty else { return }
        var session = currentSession ?? ChatSession(
            provider: provider ?? selectedProvider.rawValue,
            messages: messages
        )
        session.messages = messages
        session.provider = provider ?? selectedProvider.rawValue
        HistoryManager.shared.save(session: session)
        currentSession = session

        // Chibi dùng Gemini Live nên tự động trích xuất Memory từ câu người dùng
        // sau khi đã có câu trả lời. Không ảnh hưởng luồng chat chữ thông thường.
        if provider == "Chat chữ + Gemini Live", autoMemory,
           messages.last?.role == .assistant,
           let userMessage = messages.dropLast().last(where: { $0.role == .user }) {
            let key = "\(session.id.uuidString)|\(userMessage.content)"
            if !extractedVoiceMemoryKeys.contains(key) {
                extractedVoiceMemoryKeys.insert(key)
                Task { await extractVoiceMemory(from: userMessage.content) }
            }
        }
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || !pendingAttachments.isEmpty), !isSending else { return }
        let attachmentsToSend = pendingAttachments
        let userContent = trimmed.isEmpty && !attachmentsToSend.isEmpty ? "Hãy phân tích ảnh đính kèm." : trimmed
        messages.append(ChatMessage(role: .user, content: userContent, attachments: attachmentsToSend))
        inputText = ""
        pendingAttachments = []
        isSending = true
        errorMessage = nil

        Task {
            do {
                let reply = try await fetchWithRetry()
                messages.append(ChatMessage(role: .assistant, content: reply))
                if autoSpeakReplies { onSpeakReply?(reply, voiceGender) }
                saveCurrentSession()
                if autoMemory {
                    await extractMemory(from: trimmed)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func extractMemory(from userMessage: String) async {
        let prompt = HistoryManager.extractMemoryPrompt(from: userMessage)
        let key = KeychainHelper.read(forKey: selectedProvider.keychainKey) ?? ""
        guard !key.isEmpty else { return }

        let extractMsg = [ChatMessage(role: .user, content: prompt)]
        do {
            let result: String
            switch selectedProvider {
            case .openAI:    result = try await openAIService.sendMessage(history: extractMsg, apiKey: key, model: openAIModel)
            case .anthropic: result = try await anthropicService.sendMessage(history: extractMsg, apiKey: key, model: anthropicModel)
            case .gemini:    result = try await geminiService.sendMessage(history: extractMsg, apiKey: key, model: geminiModel)
            case .grok:      result = try await grokService.sendMessage(history: extractMsg, apiKey: key, model: grokModel)
            case .deepseek:  result = try await deepseekService.sendMessage(history: extractMsg, apiKey: key, model: deepseekModel)
            case .groq:      result = try await groqService.sendMessage(history: extractMsg, apiKey: key, model: groqModel)
            }
            if result.hasPrefix("MEMORY:") {
                let memory = result.replacingOccurrences(of: "MEMORY:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                HistoryManager.shared.addMemory(memory)
            }
        } catch { }
    }

    private func extractVoiceMemory(from userMessage: String) async {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let key = KeychainHelper.read(forKey: AIProviderKind.gemini.keychainKey), !key.isEmpty else { return }

        let prompt = """
        Bạn đang xây dựng bộ nhớ dài hạn cho một trợ lý AI.
        Đọc câu nói của người dùng bên dưới và chỉ trích xuất những thông tin có giá trị lâu dài, có khả năng giúp trợ lý hiểu và hỗ trợ người dùng tốt hơn trong các cuộc trò chuyện sau.
        Ưu tiên: tên/cách xưng hô, nghề nghiệp hoặc dự án lâu dài, sở thích ổn định, thói quen, mục tiêu, yêu cầu giao tiếp đặc biệt và các thông tin người dùng chủ động muốn trợ lý ghi nhớ.
        Không lưu lời chào, cảm xúc nhất thời, câu hỏi thông thường, thông tin chỉ đúng trong vài phút, hoặc suy đoán không được người dùng nói rõ.
        Nếu có nhiều thông tin, trả về mỗi thông tin trên một dòng theo đúng format: MEMORY: <nội dung>
        Nếu không có gì đáng nhớ, trả về đúng: NONE
        Chỉ trả về các dòng MEMORY hoặc NONE, không giải thích thêm.

        Câu nói của người dùng:
        """
        + trimmed

        let extractMsg = [ChatMessage(role: .user, content: prompt)]
        do {
            let result = try await geminiService.sendMessage(history: extractMsg, apiKey: key, model: geminiModel)
            let memories = result
                .components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard value.hasPrefix("MEMORY:") else { return nil }
                    let memory = value.replacingOccurrences(of: "MEMORY:", with: "", options: .anchored)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return memory.isEmpty ? nil : memory
                }

            for memory in memories.prefix(5) {
                HistoryManager.shared.addMemory(memory)
            }
        } catch {
            // Memory là tính năng bổ trợ; lỗi trích xuất không được làm gián đoạn cuộc gọi.
        }
    }

    private func fetchWithRetry(maxAttempts: Int = 3) async throws -> String {
        var lastError: Error = AIProviderError.invalidResponse
        for attempt in 1...maxAttempts {
            do { return try await fetchReply() }
            catch AIProviderError.busy(let msg) {
                lastError = AIProviderError.busy(msg)
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        throw lastError
    }

    private func fetchReply() async throws -> String {
        let key = KeychainHelper.read(forKey: selectedProvider.keychainKey) ?? ""
        var history = messages
        if let memoryPrompt = HistoryManager.shared.memorySystemPrompt {
            history.insert(ChatMessage(role: .system, content: memoryPrompt), at: 0)
        }
        switch selectedProvider {
        case .openAI:    return try await openAIService.sendMessage(history: history, apiKey: key, model: openAIModel)
        case .anthropic: return try await anthropicService.sendMessage(history: history, apiKey: key, model: anthropicModel)
        case .gemini:    return try await geminiService.sendMessage(history: history, apiKey: key, model: geminiModel)
        case .grok:      return try await grokService.sendMessage(history: history, apiKey: key, model: grokModel)
        case .deepseek:  return try await deepseekService.sendMessage(history: history, apiKey: key, model: deepseekModel)
        case .groq:      return try await groqService.sendMessage(history: history, apiKey: key, model: groqModel)
        }
    }

    func removePendingAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func addPendingAttachment(_ attachment: ChatAttachment) {
        guard !pendingAttachments.contains(where: { $0.name == attachment.name && $0.data == attachment.data }) else { return }
        pendingAttachments.append(attachment)
    }

    func clear() {
        startNewChat()
    }
}
