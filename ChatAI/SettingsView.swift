import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var openAIKey: String = KeychainHelper.read(forKey: AIProviderKind.openAI.keychainKey) ?? ""
    @State private var anthropicKey: String = KeychainHelper.read(forKey: AIProviderKind.anthropic.keychainKey) ?? ""
    @State private var geminiKey: String = KeychainHelper.read(forKey: AIProviderKind.gemini.keychainKey) ?? ""
    @State private var grokKey: String = KeychainHelper.read(forKey: AIProviderKind.grok.keychainKey) ?? ""
    @State private var deepseekKey: String = KeychainHelper.read(forKey: AIProviderKind.deepseek.keychainKey) ?? ""
    @State private var groqKey: String = KeychainHelper.read(forKey: AIProviderKind.groq.keychainKey) ?? ""
    @State private var azureKey: String = KeychainHelper.read(forKey: "azure_tts_key") ?? ""
    @State private var azureRegion: String = KeychainHelper.read(forKey: "azure_tts_region") ?? ""
    @AppStorage("model_gemini") private var geminiModel: String = AIProviderKind.gemini.defaultModel
    @AppStorage("model_groq") private var groqModel: String = AIProviderKind.groq.defaultModel
    @AppStorage("autoSpeakReplies") private var autoSpeakReplies: Bool = false
    @AppStorage("voiceGender") private var voiceGenderRaw: String = VoiceGender.female.rawValue
    @State private var pickerMode: ModelPickerMode?

    var body: some View {
        NavigationStack {
            Form {
                Section("Giọng nói") {
                    Toggle("Tự động đọc to câu trả lời", isOn: $autoSpeakReplies)
                    Picker("Giọng đọc", selection: $voiceGenderRaw) {
                        ForEach(VoiceGender.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                    }
                }
                Section { SecureField("Azure TTS key (F0 miễn phí)", text: $azureKey); TextField("Region (vd: southeastasia)", text: $azureRegion) } header: { Text("Azure TTS – giọng neural tiếng Việt") } footer: { Text("Đăng ký miễn phí tại portal.azure.com → Cognitive Services → Speech. Key F0 cho 500k ký tự/tháng. Nếu để trống, app dùng giọng iOS mặc định.").font(.caption) }
                Section("ChatGPT (OpenAI)") { SecureField("sk-...", text: $openAIKey) }
                Section("Claude (Anthropic)") { SecureField("sk-ant-...", text: $anthropicKey) }
                Section("Gemini (Google)") {
                    SecureField("AIza...", text: $geminiKey)
                    Text("Model đang dùng: \(geminiModel)").font(.footnote).foregroundColor(.secondary)
                    Button("Xem danh sách model Gemini") { pickerMode = .gemini }
                }
                Section("Grok (xAI)") { SecureField("xai-...", text: $grokKey) }
                Section("DeepSeek") { SecureField("sk-...", text: $deepseekKey) }
                Section("Groq (Llama – Miễn phí)") {
                    SecureField("gsk_...", text: $groqKey)
                    Text("Model đang dùng: \(groqModel)").font(.footnote).foregroundColor(.secondary)
                    Button("Xem danh sách model Groq") { pickerMode = .groq }
                }
                Section { Text("API key được lưu trong Keychain của máy, không gửi đi đâu khác ngoài provider tương ứng.").font(.footnote).foregroundColor(.secondary) }
            }
            .navigationTitle("Cài đặt")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") {
                        KeychainHelper.save(openAIKey, forKey: AIProviderKind.openAI.keychainKey)
                        KeychainHelper.save(anthropicKey, forKey: AIProviderKind.anthropic.keychainKey)
                        KeychainHelper.save(geminiKey, forKey: AIProviderKind.gemini.keychainKey)
                        KeychainHelper.save(grokKey, forKey: AIProviderKind.grok.keychainKey)
                        KeychainHelper.save(deepseekKey, forKey: AIProviderKind.deepseek.keychainKey)
                        KeychainHelper.save(groqKey, forKey: AIProviderKind.groq.keychainKey)
                        KeychainHelper.save(azureKey, forKey: "azure_tts_key")
                        KeychainHelper.save(azureRegion, forKey: "azure_tts_region")
                        dismiss()
                    }
                }
            }
            .sheet(item: $pickerMode) { mode in
                ModelPickerView(title: mode == .gemini ? "Chọn model Gemini" : "Chọn model Groq", currentModel: mode == .gemini ? $geminiModel : $groqModel, fetch: { mode == .gemini ? try await GeminiModelFetcher.fetchModels(apiKey: geminiKey) : try await GroqModelFetcher.fetchModels(apiKey: groqKey) })
            }
        }
    }
}

enum ModelPickerMode: String, Identifiable { case gemini, groq; var id: String { rawValue } }

struct ModelPickerView: View {
    let title: String
    @Binding var currentModel: String
    let fetch: () async throws -> [String]
    @Environment(\.dismiss) private var dismiss
    @State private var models: [String] = []
    @State private var isLoading = true
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView("Đang hỏi server...") }
                else if let errorText { VStack(spacing: 12) { Text(errorText).font(.footnote).foregroundColor(.red).padding(); Button("Thử lại") { Task { await load() } } } }
                else if models.isEmpty { Text("Không tìm thấy model nào.") }
                else { List(models, id: \.self) { model in Button { currentModel = model; dismiss() } label: { HStack { Text(model); Spacer(); if model == currentModel { Image(systemName: "checkmark").foregroundColor(.blue) } } } } }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } } }
            .task { await load() }
        }
    }
    private func load() async { isLoading = true; errorText = nil; do { models = try await fetch() } catch { errorText = error.localizedDescription }; isLoading = false }
}
