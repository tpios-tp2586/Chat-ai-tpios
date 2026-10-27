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
                        RoundedRectangle(cornerRadius: 9)
                            .fill(option.accent)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: option == theme ? "checkmark" : "paintpalette.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if option == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(option.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Chủ đề giao diện")
        } footer: {
            Text("Lựa chọn được lưu tự động. Chủ đề đang được thiết lập trước tiên; màu sắc sẽ được áp dụng dần cho các màn hình trong các bước tiếp theo.")
        }
    }
}
