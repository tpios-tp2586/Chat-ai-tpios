import SwiftUI
import PhotosUI
import UIKit

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
    @AppStorage(ChatAIThemeStore.accentKey) private var customAccentHex = ""

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
                        NavigationLink {
                            ThemeAndModelView(
                                openAIKey: $openAIKey, anthropicKey: $anthropicKey, geminiKey: $geminiKey,
                                grokKey: $grokKey, deepseekKey: $deepseekKey, groqKey: $groqKey,
                                openAIModel: $openAIModel, anthropicModel: $anthropicModel, geminiModel: $geminiModel,
                                grokModel: $grokModel, deepseekModel: $deepseekModel, groqModel: $groqModel,
                                selectedProviderRaw: $selectedProviderRaw
                            )
                        } label: {
                            settingRowLabel("Model AI", value: currentModel, icon: .provider)
                        }
                        settingToggle("Tự động đọc to câu trả lời", isOn: $autoSpeakReplies, icon: .voice)
                    }

                    settingsSection("GIAO DIỆN", icon: .settings) {
                        NavigationLink {
                            ThemeAndModelView(
                                openAIKey: $openAIKey, anthropicKey: $anthropicKey, geminiKey: $geminiKey,
                                grokKey: $grokKey, deepseekKey: $deepseekKey, groqKey: $groqKey,
                                openAIModel: $openAIModel, anthropicModel: $anthropicModel, geminiModel: $geminiModel,
                                grokModel: $grokModel, deepseekModel: $deepseekModel, groqModel: $groqModel,
                                selectedProviderRaw: $selectedProviderRaw,
                                initialTab: 0
                            )
                        } label: {
                            settingRowLabel("Chủ đề", value: theme.title, icon: .settings)
                        }
                    }

                    settingsSection("AI MEMORY", icon: .memory) {
                        settingToggle("AI Memory", isOn: $autoMemory, icon: .memory)
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
            .background { ChatAIThemeBackground(theme: theme) }
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
    @AppStorage("chatAI.themeOpacity") private var themeOpacity = 0.70
    @AppStorage("chatAI.wallpaperDarkness") private var wallpaperDarkness = 0.55
    @AppStorage("chatAI.wallpaperBrightness") private var wallpaperBrightness = 1.0
    @AppStorage("chatAI.wallpaperSaturation") private var wallpaperSaturation = 1.0
    @AppStorage(ChatAIThemeStore.accentKey) private var accentHex = ""
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var wallpaperError: String?
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
    @Binding var selectedProviderRaw: String

    init(
        openAIKey: Binding<String>, anthropicKey: Binding<String>, geminiKey: Binding<String>, grokKey: Binding<String>, deepseekKey: Binding<String>, groqKey: Binding<String>,
        openAIModel: Binding<String>, anthropicModel: Binding<String>, geminiModel: Binding<String>, grokModel: Binding<String>, deepseekModel: Binding<String>, groqModel: Binding<String>,
        selectedProviderRaw: Binding<String>, initialTab: Int = 1
    ) {
        _openAIKey = openAIKey; _anthropicKey = anthropicKey; _geminiKey = geminiKey; _grokKey = grokKey; _deepseekKey = deepseekKey; _groqKey = groqKey
        _openAIModel = openAIModel; _anthropicModel = anthropicModel; _geminiModel = geminiModel; _grokModel = grokModel; _deepseekModel = deepseekModel; _groqModel = groqModel
        _selectedProviderRaw = selectedProviderRaw
        _tab = State(initialValue: initialTab)
    }

    private var theme: ChatAITheme { ChatAITheme(rawValue: selectedTheme) ?? .firePremium }
    private var selectedProvider: AIProviderKind { AIProviderKind(rawValue: selectedProviderRaw) ?? .openAI }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if tab == 0 { themeDesign } else { modelDesign }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .background { ChatAIThemeBackground(theme: theme) }
        .onChange(of: wallpaperItem) { item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    wallpaperError = "Không đọc được ảnh đã chọn."
                    return
                }
                wallpaperError = ChatAIThemeStore.saveWallpaper(data: data) ? nil : "Không thể lưu ảnh nền."
            }
        }
        .navigationTitle(tab == 0 ? "Chủ đề" : "Model AI")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(theme.accent)
    }

    private func themeTab(_ title: String, _ value: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { tab = value }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tab == value ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if tab == value { Capsule().fill(theme.accent.opacity(0.88)) }
                }
        }
        .buttonStyle(.plain)
    }

    private var themeDesign: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Chủ đề giao diện").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ChatAITheme.allCases) { option in
                    Button { selectedTheme = option.rawValue } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(LinearGradient(colors: [option.accent.opacity(0.95), option.background, option.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(height: 82)
                                    .overlay(alignment: .bottomLeading) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.78)).frame(width: 42, height: 4)
                                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.30)).frame(width: 62, height: 3)
                                        }
                                        .padding(10)
                                    }
                                if option == theme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(theme.accent, in: Circle())
                                        .padding(8)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(option == theme ? option.accent : Color.white.opacity(0.10), lineWidth: option == theme ? 1.4 : 0.8))

                            Text(option.title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                            Text(option.subtitle).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Màu sắc").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 2)
            HStack(spacing: 13) {
                paletteDot("F05A36"); paletteDot("D98245"); paletteDot("C7BAA8"); paletteDot("6B4DD8")
                paletteDot("579973"); paletteDot("2B2B30"); paletteDot("8C8C91"); paletteDot("1A1A1C")
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Độ trong suốt").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(themeOpacity * 100))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                }
                Slider(value: $themeOpacity, in: 0.45...0.90, step: 0.05).tint(theme.accent)
            }
            .padding(12)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.accent.opacity(0.14), lineWidth: 1))
            VStack(alignment: .leading, spacing: 10) {
                Text("Ảnh nền toàn màn hình").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                PhotosPicker(selection: $wallpaperItem, matching: .images) {
                    Label("Chọn ảnh từ thư viện", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).padding(12)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }.buttonStyle(.plain)
                if ChatAIThemeStore.wallpaperURL != nil {
                    Button("Xóa ảnh nền", role: .destructive) {
                        if let url = ChatAIThemeStore.wallpaperURL { try? FileManager.default.removeItem(at: url) }
                        UserDefaults.standard.removeObject(forKey: ChatAIThemeStore.wallpaperKey)
                    }.font(.system(size: 12, weight: .medium))
                }
                if let wallpaperError { Text(wallpaperError).font(.system(size: 11)).foregroundStyle(.red) }
                themeSlider("Lớp phủ tối", value: $wallpaperDarkness, range: 0...0.85)
                themeSlider("Độ sáng", value: $wallpaperBrightness, range: 0.5...1.5)
                themeSlider("Độ bão hòa", value: $wallpaperSaturation, range: 0...2)
            }
            .padding(12).background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.accent.opacity(0.14), lineWidth: 1))
        }
    }

    private func themeSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\\(Int(value.wrappedValue * 100))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).tint(theme.accent)
        }
    }

    private func paletteDot(_ hex: String) -> some View {
        let color = Color(hex: hex) ?? .white
        return Button { accentHex = hex } label: {
            Circle().fill(color).frame(width: 25, height: 25)
                .overlay(Circle().stroke(Color.white.opacity(accentHex == hex ? 0.95 : 0.22), lineWidth: accentHex == hex ? 2 : 1))
                .overlay { if accentHex == hex { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
        }.buttonStyle(.plain).accessibilityLabel("Chọn màu nhấn")
    }

    private var modelDesign: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mô hình AI").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)

            VStack(spacing: 0) {
                modelRow(.openAI, subtitle: "Trò chuyện · Đa năng · Sáng tạo", model: $openAIModel, key: $openAIKey)
                modelRow(.anthropic, subtitle: "An toàn · Logic · Phân tích", model: $anthropicModel, key: $anthropicKey)
                modelRow(.gemini, subtitle: "Đa phương thức · Kết nối Google", model: $geminiModel, key: $geminiKey)
                modelRow(.grok, subtitle: "Nhanh · Thời sự · Sáng tạo", model: $grokModel, key: $grokKey)
                modelRow(.deepseek, subtitle: "Lý luận · Code · Phân tích", model: $deepseekModel, key: $deepseekKey)
                modelRow(.groq, subtitle: "Miễn phí · Nhanh · Linh hoạt", model: $groqModel, key: $groqKey)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(theme.accent.opacity(0.16), lineWidth: 1))

        }
    }

    private func fetchModels(for provider: AIProviderKind, apiKey: String) async throws -> [String] {
        switch provider {
        case .openAI: return try await OpenAIModelFetcher.fetchModels(apiKey: apiKey)
        case .anthropic: return try await AnthropicModelFetcher.fetchModels(apiKey: apiKey)
        case .gemini: return try await GeminiModelFetcher.fetchModels(apiKey: apiKey)
        case .grok: return try await GrokModelFetcher.fetchModels(apiKey: apiKey)
        case .deepseek: return try await DeepSeekModelFetcher.fetchModels(apiKey: apiKey)
        case .groq: return try await GroqModelFetcher.fetchModels(apiKey: apiKey)
        }
    }

    private func modelRow(_ provider: AIProviderKind, subtitle: String, model: Binding<String>, key: Binding<String>) -> some View {
        VStack(spacing: 0) {
            Button {
                selectedProviderRaw = provider.rawValue
            } label: {
                HStack(spacing: 9) {
                    ChatAICustomIcon(kind: .provider, color: selectedProvider == provider ? theme.accent : .secondary, theme: theme).frame(width: 19, height: 19)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.rawValue.components(separatedBy: " (").first ?? provider.rawValue).font(.system(size: 13, weight: .semibold))
                        Text(subtitle).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(selectedProvider == provider ? theme.accent : Color.secondary.opacity(0.55))
                }
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            if selectedProvider == provider {
                HStack(spacing: 7) {
                    SecureField("API key", text: key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 10))
                        .padding(.horizontal, 9)
                        .frame(height: 32)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    NavigationLink {
                        ModelPickerView(
                            title: "Chọn model",
                            currentModel: model,
                            fetch: { try await fetchModels(for: provider, apiKey: key.wrappedValue) }
                        )
                    } label: {
                        Text("Tải model")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(.bottom, 8)
            }
            if provider != .groq { Divider().opacity(0.25) }
        }
    }

    private func roleRow(_ title: String, _ subtitle: String, selected: Bool) -> some View {
        HStack(spacing: 9) {
            ChatAICustomIcon(kind: .companion, color: selected ? theme.accent : .secondary, theme: theme).frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(selected ? theme.accent : Color.secondary.opacity(0.5))
        }
        .padding(.vertical, 9)
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
            .background { ChatAIThemeBackground(theme: theme) }
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
