import SwiftUI

/// Reusable visual components for the TP Signature chat UI.
/// These views are presentation-only; they do not own chat or provider state.
enum ChatScreenStyle {
    static let horizontalInset: CGFloat = 18
    static let cardRadius: CGFloat = 22
    static let controlRadius: CGFloat = 18
}

struct ChatScreenHeader: View {
    let providerTitle: String
    let accent: Color
    let surface: Color
    let onHistory: () -> Void
    let onProvider: () -> Void
    let onCompanion: () -> Void
    let onVoice: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            headerButton("clock.arrow.circlepath", label: "Lịch sử", action: onHistory)
            VStack(spacing: 3) {
                HStack(spacing: 7) {
                    Circle().fill(accent).frame(width: 7, height: 7)
                    Text("ChatAI")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Button(action: onProvider) {
                        HStack(spacing: 4) {
                            Text(providerTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.12), in: Capsule())
                    }
                }
                Text("DESIGNED FOR YOUR FLOW")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            headerButton("person.crop.rectangle.stack", label: "ChatAI 3D", action: onCompanion)
            headerButton("waveform", label: "Thoại trực tiếp", action: onVoice)
            headerButton("slider.horizontal.3", label: "Cài đặt", action: onSettings)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(surface.opacity(0.68))
        .overlay(alignment: .bottom) {
            Rectangle().fill(accent.opacity(0.25)).frame(height: 0.5)
        }
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ChatComposerSurface<Content: View>: View {
    let accent: Color
    let surface: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: ChatScreenStyle.cardRadius, style: .continuous)
                .fill(surface)
                .overlay {
                    RoundedRectangle(cornerRadius: ChatScreenStyle.cardRadius, style: .continuous)
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

struct ChatComposerField: View {
    @Binding var text: String
    let accent: Color
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.system(size: 15))
            .lineLimit(1...5)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .tint(accent)
    }
}

struct ChatActionButton: View {
    let symbol: String
    let label: String
    let accent: Color
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : accent)
                .frame(width: 42, height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(prominent ? accent : accent.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ChatMessageCard: View {
    let text: String
    let isUser: Bool
    let accent: Color
    let surface: Color

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .lineSpacing(4)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: isUser ? 21 : 21, style: .continuous)
                    .fill(isUser ? accent : surface)
                    .overlay {
                        if !isUser {
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .stroke(Color.white.opacity(0.055), lineWidth: 1)
                        }
                    }
            }
    }
}
