import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var openAIKey = KeychainHelper.read(forKey: AIProviderKind.openAI.keychainKey) ?? ""
    @State private var anthropicKey = KeychainHelper.read(forKey: AIProviderKind.anthropic.keychainKey) ?? ""
    @State private var geminiKey = KeychainHelper.read(forKey: AIProviderKind.gemini.keychainKey) ?? ""
    @State private var grokKey = KeychainHelper.read(forKey: AIProviderKind.grok.keychainKey) ?? ""
    @State private var deepseekKey = KeychainHelper.read(forKey: AIProviderKind.deepseek.keychainKey) ?? ""
    @State private var groqKey = KeychainHelper.read(forKey: AIProviderKind.groq.keychainKey) ?? ""

    @AppStorage("model_openai") private var openAIModel = AIProviderKind.openAI.defaultModel
    @AppStorage("model_anthropic") private var anthropicModel = AIProviderKind.anthropic.defaultModel
    @AppStorage("model_gemini") private var geminiModel = AIProviderKind.gemini.defaultModel
    @AppStorage("model_grok") private var grokModel = AIProviderKind.grok.defaultModel
    @AppStorage("model_deepseek") private var deepseekModel = AIProviderKind.deepseek.defaultModel
    @AppStorage("model_groq") private var groqModel = AIProviderKind.groq.defaultModel
    @AppStorage("autoSpeakReplies") private var autoSpeakReplies = false
    @AppStorage("voiceGender") private var voiceGenderRaw = VoiceGender.female.rawValue
    @AppStorage("autoMemoryV2") private var autoMemory = false
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    @State private var pickerMode: ModelPickerMode?

    private var activeTheme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    settingsHero

                    settingsGroup("TÙY CHỈNH AI", icon: .companion) {
                        settingsRow("Giọng nói", value: voiceGenderRaw, icon: .voice) {
                            Picker("Giọng đọc", selection: $voiceGenderRaw) {
                                ForEach(VoiceGender.allCases) { voice in
                                    Text(voice.rawValue).tag(voice.rawValue)
                                }
                            }
                            .labelsHidden()
                            .tint(activeTheme.accent)
                        }
                        settingsToggle("Tự động đọc to câu trả lời", isOn: $autoSpeakReplies, icon: .voice)
                    }

                    settingsGroup("GIAO DIỆN", icon: .settings) {
                        ThemeSettingsSection()
                    }

                    settingsGroup("AI MEMORY", icon: .memory) {
                        settingsToggle("Tự động ghi nhớ thông tin", isOn: $autoMemory, icon: .memory)
                        settingsInfoRow("Lịch sử và bộ nhớ được giữ nguyên", icon: .history)
                    }

                    settingsGroup("NHÀ CUNG CẤP AI", icon: .provider) {
                        providerRow("ChatGPT · OpenAI", key: $openAIKey, model: $openAIModel, mode: .openai, placeholder: "sk-...")
                        providerRow("Claude · Anthropic", key: $anthropicKey, model: $anthropicModel, mode: .anthropic, placeholder: "sk-ant-...")
                        providerRow("Gemini · Google", key: $geminiKey, model: $geminiModel, mode: .gemini, placeholder: "AIza...")
                        providerRow("Grok · xAI", key: $grokKey, model: $grokModel, mode: .grok, placeholder: "xai-...")
                        providerRow("DeepSeek", key: $deepseekKey, model: $deepseekModel, mode: .deepseek, placeholder: "sk-...")
                        providerRow("Groq · Llama", key: $groqKey, model: $groqModel, mode: .groq, placeholder: "gsk_...")
                    }

                    Text("API key được lưu trong Keychain của máy và chỉ dùng với provider tương ứng.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ChatBrandingCredit()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(activeTheme.background.ignoresSafeArea())
            .foregroundStyle(.primary)
            .tint(activeTheme.accent)
            .preferredColorScheme(.dark)
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $pickerMode) { mode in
                ModelPickerView(
                    title: mode.title,
                    currentModel: mode.binding(
                        openAI: $openAIModel,
                        anthropic: $anthropicModel,
                        gemini: $geminiModel,
                        grok: $grokModel,
                        deepseek: $deepseekModel,
                        groq: $groqModel
                    ),
                    fetch: {
                        switch mode {
                        case .openai: return try await OpenAIModelFetcher.fetchModels(apiKey: openAIKey)
                        case .anthropic: return try await AnthropicModelFetcher.fetchModels(apiKey: anthropicKey)
                        case .gemini: return try await GeminiModelFetcher.fetchModels(apiKey: geminiKey)
                        case .grok: return try await GrokModelFetcher.fetchModels(apiKey: grokKey)
                        case .deepseek: return try await DeepSeekModelFetcher.fetchModels(apiKey: deepseekKey)
                        case .groq: return try await GroqModelFetcher.fetchModels(apiKey: groqKey)
                        }
                    }
                )
            }
        }
    }

    private var settingsHero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(activeTheme.accent.opacity(0.14))
                ChatAICustomIcon(kind: .companion, color: activeTheme.accent, theme: activeTheme)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 60, height: 60)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(activeTheme.accent.opacity(0.38), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("CHAT AI")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(activeTheme.accent)
                Text("Tùy chỉnh trợ lý của anh")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Giọng nói · giao diện · model · bộ nhớ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(activeTheme.accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func settingsGroup<Content: View>(_ title: String, icon: ChatAIIconKind, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ChatAICustomIcon(kind: icon, color: activeTheme.accent, theme: activeTheme)
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(activeTheme.accent)
                Spacer()
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(activeTheme.accent.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private func settingsRow(_ title: String, value: String, icon: ChatAIIconKind, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(value).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(.vertical, 3)
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>, icon: ChatAIIconKind) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(activeTheme.accent)
        }
        .padding(.vertical, 7)
    }

    private func settingsInfoRow(_ title: String, icon: ChatAIIconKind) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon)
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func iconBadge(_ kind: ChatAIIconKind) -> some View {
        ChatAICustomIcon(kind: kind, color: activeTheme.accent, theme: activeTheme)
            .frame(width: 18, height: 18)
            .frame(width: 34, height: 34)
            .background(activeTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func providerRow(_ title: String, key: Binding<String>, model: Binding<String>, mode: ModelPickerMode, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                iconBadge(.provider)
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            SecureField(placeholder, text: key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 11)
                .frame(height: 42)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(activeTheme.accent.opacity(0.13), lineWidth: 1)
                }
            Button {
                pickerMode = mode
            } label: {
                HStack(spacing: 9) {
                    ChatAICustomIcon(kind: .provider, color: activeTheme.accent, theme: activeTheme)
                        .frame(width: 16, height: 16)
                    Text(model.wrappedValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(activeTheme.accent)
                }
                .padding(.horizontal, 11)
                .frame(height: 40)
                .background(activeTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }

    private func saveAndDismiss() {
        KeychainHelper.save(openAIKey, forKey: AIProviderKind.openAI.keychainKey)
        KeychainHelper.save(anthropicKey, forKey: AIProviderKind.anthropic.keychainKey)
        KeychainHelper.save(geminiKey, forKey: AIProviderKind.gemini.keychainKey)
        KeychainHelper.save(grokKey, forKey: AIProviderKind.grok.keychainKey)
        KeychainHelper.save(deepseekKey, forKey: AIProviderKind.deepseek.keychainKey)
        KeychainHelper.save(groqKey, forKey: AIProviderKind.groq.keychainKey)
        dismiss()
    }
}

// MARK: - ModelPickerMode

enum ModelPickerMode: String, Identifiable {
    case openai, anthropic, gemini, grok, deepseek, groq

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openai: return "Chọn model OpenAI"
        case .anthropic: return "Chọn model Anthropic"
        case .gemini: return "Chọn model Gemini"
        case .grok: return "Chọn model Grok"
        case .deepseek: return "Chọn model DeepSeek"
        case .groq: return "Chọn model Groq"
        }
    }

    func binding(openAI: Binding<String>, anthropic: Binding<String>, gemini: Binding<String>, grok: Binding<String>, deepseek: Binding<String>, groq: Binding<String>) -> Binding<String> {
        switch self {
        case .openai: return openAI
        case .anthropic: return anthropic
        case .gemini: return gemini
        case .grok: return grok
        case .deepseek: return deepseek
        case .groq: return groq
        }
    }
}

struct ModelPickerView: View {
    let title: String
    @Binding var currentModel: String
    let fetch: () async throws -> [String]
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue
    @State private var models: [String] = []
    @State private var isLoading = true
    @State private var errorText: String?

    private var activeTheme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Đang hỏi server...")
                } else if let errorText {
                    VStack(spacing: 12) {
                        Text(errorText).font(.footnote).foregroundStyle(.red).padding()
                        Button("Thử lại") { Task { await load() } }
                    }
                } else if models.isEmpty {
                    Text("Không tìm thấy model nào.")
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 9) {
                            ForEach(models, id: \.self) { model in
                                Button {
                                    currentModel = model
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        ChatAICustomIcon(kind: .provider, color: activeTheme.accent, theme: activeTheme)
                                            .frame(width: 18, height: 18)
                                            .frame(width: 38, height: 38)
                                            .background(activeTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        Text(model)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: model == currentModel ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundStyle(model == currentModel ? activeTheme.accent : Color.secondary)
                                    }
                                    .padding(11)
                                    .background(activeTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .stroke(activeTheme.accent.opacity(model == currentModel ? 0.65 : 0.18), lineWidth: model == currentModel ? 1.2 : 0.8)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .background(activeTheme.background)
                }
            }
            .navigationTitle(title)
            .tint(activeTheme.accent)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        do { models = try await fetch() }
        catch { errorText = error.localizedDescription }
        isLoading = false
    }
}
