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
    @AppStorage("selectedProvider") private var selectedProviderRaw = AIProviderKind.openAI.rawValue
    @AppStorage("voiceGender") private var voiceGenderRaw = VoiceGender.female.rawValue
    @AppStorage("autoMemoryV2") private var autoMemory = false
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var theme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }
    private var currentModel: String {
        switch AIProviderKind(rawValue: selectedProviderRaw) ?? .openAI {
        case .openAI: return openAIModel
        case .anthropic: return anthropicModel
        case .gemini: return geminiModel
        case .grok: return grokModel
        case .deepseek: return deepseekModel
        case .groq: return groqModel
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection("TÙY CHỈNH AI", icon: .companion) {
                        settingRow("Giọng nói", value: voiceGenderRaw, icon: .voice) {
                            Picker("Giọng đọc", selection: $voiceGenderRaw) {
                                ForEach(VoiceGender.allCases) { voice in
                                    Text(voice.rawValue).tag(voice.rawValue)
                                }
                            }
                            .labelsHidden()
                            .tint(theme.accent)
                        }
                        settingRow("Vai trò", value: "Bạn đồng hành", icon: .companion)
                        NavigationLink {
                            ThemeAndModelView(
                                openAIKey: $openAIKey, anthropicKey: $anthropicKey, geminiKey: $geminiKey,
                                grokKey: $grokKey, deepseekKey: $deepseekKey, groqKey: $groqKey,
                                openAIModel: $openAIModel, anthropicModel: $anthropicModel, geminiModel: $geminiModel,
                                grokModel: $grokModel, deepseekModel: $deepseekModel, groqModel: $groqModel
                            )
                        } label: {
                            settingRowLabel("Model AI", value: currentModel, icon: .provider)
                        }
                        settingRow("Avatar", value: "Kawaii Girl", icon: .companion)
                        settingRow("Ngôn ngữ", value: "Tiếng Việt", icon: .settings)
                        settingToggle("Tự động đọc to câu trả lời", isOn: $autoSpeakReplies, icon: .voice)
                    }

                    settingsSection("GIAO DIỆN", icon: .settings) {
                        NavigationLink {
                            ThemeAndModelView(
                                openAIKey: $openAIKey, anthropicKey: $anthropicKey, geminiKey: $geminiKey,
                                grokKey: $grokKey, deepseekKey: $deepseekKey, groqKey: $groqKey,
                                openAIModel: $openAIModel, anthropicModel: $anthropicModel, geminiModel: $geminiModel,
                                grokModel: $grokModel, deepseekModel: $deepseekModel, groqModel: $groqModel,
                                initialTab: 0
                            )
                        } label: {
                            settingRowLabel("Chủ đề", value: theme.title, icon: .settings)
                        }
                        settingRow("Kiểu hiển thị", value: "Cân bằng", icon: .history)
                        settingRow("Hiệu ứng", value: "Mượt mà", icon: .voice)
                    }

                    settingsSection("TÀI KHOẢN", icon: .memory) {
                        settingRow("Thông tin cá nhân", value: "Anh Phong", icon: .companion)
                        settingToggle("AI Memory", isOn: $autoMemory, icon: .memory)
                        settingRow("Lịch sử chat", value: "Mở từ thanh dưới", icon: .history)
                    }

                    Text("API key được lưu trong Keychain của máy và chỉ dùng với provider tương ứng.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
            .background(theme.background.ignoresSafeArea())
            .foregroundStyle(.primary)
            .tint(theme.accent)
            .preferredColorScheme(.dark)
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, icon: ChatAIIconKind, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                ChatAICustomIcon(kind: icon, color: theme.accent, theme: theme)
                    .frame(width: 15, height: 15)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .tracking(1.0)
            }
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.accent.opacity(0.20), lineWidth: 1)
                }
        }
    }

    private func settingRowLabel(_ title: String, value: String, icon: ChatAIIconKind) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer(minLength: 8)
            Text(value).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func settingRow(_ title: String, value: String, icon: ChatAIIconKind, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            trailing()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>, icon: ChatAIIconKind) -> some View {
        HStack(spacing: 10) {
            iconBadge(icon)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(theme.accent)
        }
        .padding(.vertical, 7)
    }

    private func iconBadge(_ kind: ChatAIIconKind) -> some View {
        ChatAICustomIcon(kind: kind, color: theme.accent, theme: theme)
            .frame(width: 17, height: 17)
            .frame(width: 28, height: 28)
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

struct ThemeAndModelView: View {
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue
    @State private var tab: Int

    @Binding var openAIKey: String
    @Binding var anthropicKey: String
    @Binding var geminiKey: String
    @Binding var grokKey: String
    @Binding var deepseekKey: String
    @Binding var groqKey: String
    @Binding var openAIModel: String
    @Binding var anthropicModel: String
    @Binding var geminiModel: String
    @Binding var grokModel: String
    @Binding var deepseekModel: String
    @Binding var groqModel: String

    init(
        openAIKey: Binding<String>, anthropicKey: Binding<String>, geminiKey: Binding<String>, grokKey: Binding<String>, deepseekKey: Binding<String>, groqKey: Binding<String>,
        openAIModel: Binding<String>, anthropicModel: Binding<String>, geminiModel: Binding<String>, grokModel: Binding<String>, deepseekModel: Binding<String>, groqModel: Binding<String>,
        initialTab: Int = 1
    ) {
        _openAIKey = openAIKey; _anthropicKey = anthropicKey; _geminiKey = geminiKey; _grokKey = grokKey; _deepseekKey = deepseekKey; _groqKey = groqKey
        _openAIModel = openAIModel; _anthropicModel = anthropicModel; _geminiModel = geminiModel; _grokModel = grokModel; _deepseekModel = deepseekModel; _groqModel = groqModel
        _tab = State(initialValue: initialTab)
    }

    private var theme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $tab) {
                    Text("Chủ đề").tag(0)
                    Text("Mô hình").tag(1)
                }
                .pickerStyle(.segmented)
                .tint(theme.accent)
                if tab == 0 { themeCards } else { modelCards }
            }
            .padding(14)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Chủ đề & Mô hình")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(theme.accent)
    }

    private var themeCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chủ đề giao diện")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ChatAITheme.allCases) { option in
                    Button { selectedTheme = option.rawValue } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [option.accent, option.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 78)
                                .overlay(alignment: .topTrailing) {
                                    if option.rawValue == selectedTheme {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white).padding(8)
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(option.accent.opacity(option.rawValue == selectedTheme ? 0.9 : 0.25), lineWidth: option.rawValue == selectedTheme ? 1.5 : 0.8)
                                }
                            Text(option.title).font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text(option.subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var modelCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mô hình AI").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            providerCard(.openAI, model: $openAIModel, key: $openAIKey)
            providerCard(.anthropic, model: $anthropicModel, key: $anthropicKey)
            providerCard(.gemini, model: $geminiModel, key: $geminiKey)
            providerCard(.grok, model: $grokModel, key: $grokKey)
            providerCard(.deepseek, model: $deepseekModel, key: $deepseekKey)
            providerCard(.groq, model: $groqModel, key: $groqKey)
        }
    }

    private func providerCard(_ provider: AIProviderKind, model: Binding<String>, key: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ChatAICustomIcon(kind: .provider, color: theme.accent, theme: theme).frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue).font(.system(size: 14, weight: .semibold))
                    Text(model.wrappedValue).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            SecureField("API key", text: key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack {
                Button("Model mặc định") { model.wrappedValue = provider.defaultModel }
                Spacer()
                Text("Keychain").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.accent)
        }
        .padding(11)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(theme.accent.opacity(0.16), lineWidth: 1) }
    }
}

enum ModelPickerMode: String, Identifiable {
    case openai, anthropic, gemini, grok, deepseek, groq
    var id: String { rawValue }
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

    private var theme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Đang hỏi server...")
                } else if let errorText {
                    VStack(spacing: 12) {
                        Text(errorText).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                        Button("Thử lại") { Task { await load() } }
                    }
                    .padding()
                } else if models.isEmpty {
                    Text("Không tìm thấy model nào.").foregroundStyle(.secondary)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 9) {
                            ForEach(models, id: \.self) { model in
                                Button {
                                    currentModel = model
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        ChatAICustomIcon(kind: .provider, color: theme.accent, theme: theme).frame(width: 18, height: 18)
                                        Text(model).font(.system(size: 14, weight: .medium, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: model == currentModel ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundStyle(model == currentModel ? theme.accent : Color.secondary)
                                    }
                                    .padding(12)
                                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.accent.opacity(model == currentModel ? 0.55 : 0.15), lineWidth: model == currentModel ? 1.1 : 0.8) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        do { models = try await fetch() } catch { errorText = error.localizedDescription }
        isLoading = false
    }
}
