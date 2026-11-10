import Foundation
import Security

// MARK: - API Services

struct OpenAICompatibleService {
    let baseURL: URL
    func sendMessage(history: [ChatMessage], apiKey: String, model: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        if history.contains(where: { !$0.attachments.isEmpty }) && baseURL.host != "api.openai.com" {
            throw AIProviderError.server("Nhà cung cấp/model đang chọn chưa được bật gửi ảnh trong ChatAI. Hãy chuyển sang model OpenAI có hỗ trợ ảnh.")
        }
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var messages: [[String: Any]] = []
        for message in history {
            var item: [String: Any] = ["role": message.role.rawValue, "content": message.content]
            if !message.attachments.isEmpty {
                var parts: [[String: Any]] = [["type": "text", "text": message.content]]
                for attachment in message.attachments {
                    guard attachment.mimeType.hasPrefix("image/") else {
                        throw AIProviderError.server("Chỉ hỗ trợ đính kèm ảnh trực tiếp cho model này. Tệp văn bản/PDF cần được trích xuất thành nội dung trước khi gửi.")
                    }
                    parts.append(["type": "image_url", "image_url": ["url": "data:\(attachment.mimeType);base64,\(attachment.data.base64EncodedString())"]])
                }
                item["content"] = parts
            }
            messages.append(item)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "messages": messages])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 503 { throw AIProviderError.busy(text) }
            throw AIProviderError.server(text)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any] else { throw AIProviderError.invalidResponse }
        if let content = msg["content"] as? String { return content }
        if let parts = msg["content"] as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        throw AIProviderError.invalidResponse
    }
}

struct AnthropicService {
    func sendMessage(history: [ChatMessage], apiKey: String, model: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var messages: [[String: Any]] = []
        for message in history where message.role != .system {
            var content: Any = message.content
            if !message.attachments.isEmpty {
                var blocks: [[String: Any]] = [["type": "text", "text": message.content]]
                for attachment in message.attachments {
                    guard ["image/jpeg", "image/png", "image/gif", "image/webp"].contains(attachment.mimeType) else {
                        throw AIProviderError.server("Claude nhận ảnh JPEG, PNG, GIF hoặc WebP. Vui lòng chọn ảnh định dạng được hỗ trợ.")
                    }
                    blocks.append(["type": "image", "source": ["type": "base64", "media_type": attachment.mimeType, "data": attachment.data.base64EncodedString()]])
                }
                content = blocks
            }
            messages.append(["role": message.role == .assistant ? "assistant" : "user", "content": content])
        }
        var payload: [String: Any] = ["model": model, "max_tokens": 1024, "messages": messages]
        let systemPrompt = history.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        if !systemPrompt.isEmpty { payload["system"] = systemPrompt }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 503 || code == 529 { throw AIProviderError.busy(text) }
            throw AIProviderError.server(text)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { throw AIProviderError.invalidResponse }
        return content.compactMap { $0["text"] as? String }.joined(separator: "\n")
    }
}

struct GeminiService {
    func sendMessage(history: [ChatMessage], apiKey: String, model: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw AIProviderError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var contents: [[String: Any]] = []
        for message in history where message.role != .system {
            var parts: [[String: Any]] = [["text": message.content]]
            for attachment in message.attachments {
                guard attachment.mimeType.hasPrefix("image/") else {
                    throw AIProviderError.server("Gemini đang nhận ảnh đính kèm; tệp khác cần được trích xuất thành văn bản trước khi gửi.")
                }
                parts.append(["inlineData": ["mimeType": attachment.mimeType, "data": attachment.data.base64EncodedString()]])
            }
            contents.append(["role": message.role == .assistant ? "model" : "user", "parts": parts])
        }
        var payload: [String: Any] = ["contents": contents]
        let systemPrompt = history.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        if !systemPrompt.isEmpty {
            payload["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 503 { throw AIProviderError.busy(text) }
            throw AIProviderError.server(text)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { throw AIProviderError.invalidResponse }
        return parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
    }
}

enum GroqModelFetcher {
    static func fetchModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AIProviderError.server(String(data: data, encoding: .utf8) ?? "unknown error") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let list = json["data"] as? [[String: Any]] else { throw AIProviderError.invalidResponse }
        let excluded = ["whisper", "tts", "guard", "stt", "audio", "moderation", "playai"]
        return list.compactMap { item -> String? in
            guard let id = item["id"] as? String else { return nil }
            let lower = id.lowercased()
            if excluded.contains(where: { lower.contains($0) }) { return nil }
            if let active = item["active"] as? Bool, !active { return nil }
            return id
        }.sorted()
    }
}

enum GeminiModelFetcher {
    static func fetchModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw AIProviderError.invalidResponse }
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AIProviderError.server(String(data: data, encoding: .utf8) ?? "unknown error") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let list = json["models"] as? [[String: Any]] else { throw AIProviderError.invalidResponse }
        return list.compactMap { item -> String? in
            guard let methods = item["supportedGenerationMethods"] as? [String], methods.contains("generateContent"), let name = item["name"] as? String else { return nil }
            return name.replacingOccurrences(of: "models/", with: "")
        }.sorted()
    }
}
enum OpenAIModelFetcher {
    static func fetchModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIProviderError.server(String(data: data, encoding: .utf8) ?? "unknown error")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]]
        else { throw AIProviderError.invalidResponse }
        // Chỉ lấy model chat (gpt-*)
        return list
            .compactMap { $0["id"] as? String }
            .filter { $0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") }
            .sorted()
    }
}

enum AnthropicModelFetcher {
    static func fetchModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIProviderError.server(String(data: data, encoding: .utf8) ?? "unknown error")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]]
        else { throw AIProviderError.invalidResponse }
        return list.compactMap { $0["id"] as? String }.sorted()
    }
}

enum GrokModelFetcher {
    static func fetchModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIProviderError.server(String(data: data, encoding: .utf8) ?? "unknown error")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]]
        else { throw AIProviderError.invalidResponse }
        return list.compactMap { $0["id"] as? String }.sorted()
    }
}

enum DeepSeekModelFetcher {
    static func fetchModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIProviderError.server(String(data: data, encoding: .utf8) ?? "unknown error")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]]
        else { throw AIProviderError.invalidResponse }
        return list.compactMap { $0["id"] as? String }.sorted()
    }
}

enum KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }
    static func read(forKey key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
