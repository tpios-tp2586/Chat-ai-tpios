import SwiftUI

struct ThemeSettingsSection: View {
    @AppStorage(ChatAIThemeStore.storageKey) private var selectedTheme = ChatAITheme.firePremium.rawValue

    private var theme: ChatAITheme {
        ChatAITheme(rawValue: selectedTheme) ?? .firePremium
    }

    var body: some View {
        Section {
            ForEach(ChatAITheme.allCases) { option in
                Button {
                    selectedTheme = option.rawValue
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [option.accent, option.accent.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: option == theme ? "checkmark" : "paintpalette.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(option.accent.opacity(0.8), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 6)
                        if option == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(option.accent)
                        }
                    }
                    .padding(10)
                    .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(option.accent.opacity(option == theme ? 0.62 : 0.18), lineWidth: option == theme ? 1.2 : 0.8))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Chủ đề giao diện")
        } footer: {
            Text("Lựa chọn được lưu tự động và áp dụng cho giao diện chat, thanh công cụ, lịch sử, AI Memory, Cài đặt và màn hình trò chuyện thoại.")
        }
    }
}
