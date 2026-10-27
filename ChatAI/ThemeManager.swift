import SwiftUI

/// Shared persisted theme selection for ChatAI.
/// Existing chat, provider and voice logic remains independent of the selected theme.
enum ChatAITheme: String, CaseIterable, Identifiable {
    case firePremium = "firePremium"
    case sunrise = "sunrise"
    case nature = "nature"
    case minimal = "minimal"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firePremium: return "Hỏa cao cấp"
        case .sunrise: return "Bình minh"
        case .nature: return "Thiên nhiên"
        case .minimal: return "Tối giản"
        }
    }

    var subtitle: String {
        switch self {
        case .firePremium: return "Đỏ cam · Than chì · Ánh kim"
        case .sunrise: return "Cam ấm · Hoàng hôn"
        case .nature: return "Xanh trầm · Than chì"
        case .minimal: return "Trung tính · Tinh gọn"
        }
    }

    var accent: Color {
        switch self {
        case .firePremium: return Color(red: 0.941, green: 0.353, blue: 0.212)
        case .sunrise: return Color(red: 1.0, green: 0.49, blue: 0.25)
        case .nature: return Color(red: 0.30, green: 0.62, blue: 0.43)
        case .minimal: return Color(red: 0.72, green: 0.72, blue: 0.75)
        }
    }

    var background: Color {
        switch self {
        case .firePremium: return Color(red: 0.078, green: 0.078, blue: 0.078)
        case .sunrise: return Color(red: 0.12, green: 0.075, blue: 0.065)
        case .nature: return Color(red: 0.055, green: 0.09, blue: 0.075)
        case .minimal: return Color(red: 0.09, green: 0.09, blue: 0.10)
        }
    }

    var surface: Color {
        let opacity = UserDefaults.standard.object(forKey: "chatAI.themeOpacity") as? Double ?? 0.70
        switch self {
        case .firePremium: return Color(red: 0.141, green: 0.129, blue: 0.122).opacity(opacity)
        case .sunrise: return Color(red: 0.20, green: 0.13, blue: 0.11).opacity(opacity)
        case .nature: return Color(red: 0.11, green: 0.16, blue: 0.13).opacity(opacity)
        case .minimal: return Color(red: 0.16, green: 0.16, blue: 0.17).opacity(opacity)
        }
    }
}

enum ChatAIThemeStore {
    static let storageKey = "chatAI.selectedTheme"

    static var current: ChatAITheme {
        ChatAITheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "")
            ?? .firePremium
    }
}
