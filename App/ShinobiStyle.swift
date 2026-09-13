import SwiftUI

enum ShinobiStyle {
    static let background = Color(hex: 0x161826)
    static let surface = Color(hex: 0x232532)
    static let text = Color(hex: 0xe9e9ed)
    static let secondary = Color(hex: 0xcfd3e5)
    static let muted = Color(hex: 0xb2b6ca)
    static let subdued = Color(hex: 0x9397ab)
    static let disabled = Color(hex: 0x75798c)
    static let border = Color(hex: 0x3f424d)
    static let accent = Color(hex: 0x9184d9)
    static let accentText = Color(hex: 0xd2cefd)
    static let accentBright = Color(hex: 0xe7e5fe)
    static let accentFill = Color(hex: 0x796cbf)
    static let accentBorder = Color(hex: 0x5d5294)
    static let accentSurface = Color(hex: 0x423a6a)
    static let danger = Color(hex: 0xef9d9e)
    static let dangerBorder = Color(hex: 0x784345)
    static let dangerSurface = Color(hex: 0x382329)
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

// Inter comes from the supplied design; Japanese uses the native font fallback.
private struct ShinobiTypography: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.custom(weight == .medium ? "Inter-Medium" : "Inter-Regular", fixedSize: size))
    }
}

extension View {
    func shinobiFont(_ size: CGFloat = 15, weight: Font.Weight = .regular,
                     relativeTo: Font.TextStyle = .body) -> some View {
        modifier(ShinobiTypography(size: size, weight: weight, relativeTo: relativeTo))
    }

    func card(padding: CGFloat = 18, border: Color = ShinobiStyle.border) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(ShinobiStyle.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(border, lineWidth: 1))
    }

    func shinobiScreen() -> some View {
        background(ShinobiStyle.background).foregroundStyle(ShinobiStyle.text)
            .tint(ShinobiStyle.accentText)
            .toolbar(.hidden, for: .navigationBar)
    }
}

struct ShinobiButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary
    var height: CGFloat = 48
    @Environment(\.isEnabled) private var isEnabled

    private var foreground: Color {
        guard isEnabled else { return ShinobiStyle.disabled }
        switch kind {
        case .primary: return ShinobiStyle.accentText
        case .secondary: return ShinobiStyle.secondary
        case .destructive: return ShinobiStyle.danger
        }
    }
    private var border: Color {
        guard isEnabled else { return ShinobiStyle.border }
        switch kind {
        case .primary: return ShinobiStyle.accent
        case .secondary: return ShinobiStyle.border
        case .destructive: return ShinobiStyle.dangerBorder
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.shinobiFont(15, weight: .medium)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 12)
            .foregroundStyle(foreground)
            .background(configuration.isPressed ? border.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ShinobiHeader<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 4) {
            leading.frame(width: 84, alignment: .leading)
            Text(title).shinobiFont(17, weight: .medium, relativeTo: .headline)
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity).accessibilityAddTraits(.isHeader)
            trailing.frame(width: 84, alignment: .trailing)
        }
        .buttonStyle(.plain).shinobiFont(15)
        .frame(minHeight: 52).padding(.horizontal, 16)
        .background(ShinobiStyle.background)
    }
}

struct ShinobiBadge: View {
    let title: String
    var symbol: String? = nil
    var accented = true

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
            Text(title)
        }
        .shinobiFont(11, relativeTo: .caption)
        .foregroundStyle(accented ? ShinobiStyle.accentBright : ShinobiStyle.secondary)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(accented ? ShinobiStyle.accentSurface : ShinobiStyle.border,
                    in: RoundedRectangle(cornerRadius: 6))
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShinobiSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).shinobiFont(12, relativeTo: .caption)
                .foregroundStyle(ShinobiStyle.muted).accessibilityAddTraits(.isHeader)
            content
        }
    }
}

struct ShinobiMessage: View {
    let text: String
    var isError = false

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: isError ? "exclamationmark.circle" : "info.circle")
        }
        .shinobiFont(13, relativeTo: .footnote)
        .foregroundStyle(isError ? ShinobiStyle.danger : ShinobiStyle.secondary)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? ShinobiStyle.dangerSurface : ShinobiStyle.surface,
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isError ? ShinobiStyle.dangerBorder : ShinobiStyle.border, lineWidth: 1))
    }
}

struct ShinobiConfirmation: View {
    let title: String
    let message: String
    let actionTitle: String
    var stacked = false
    let cancel: () -> Void
    let confirm: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color(red: 0.024, green: 0.027, blue: 0.055).opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text(title).shinobiFont(17, weight: .medium, relativeTo: .headline)
                    .accessibilityAddTraits(.isHeader).accessibilityFocused($focused)
                Text(message).shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
                if stacked || dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { confirmButton; cancelButton }
                } else {
                    HStack(spacing: 10) { cancelButton; confirmButton }
                }
            }
            .card(padding: 22, border: ShinobiStyle.subdued)
            .padding(24).frame(maxWidth: 450)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear { focused = true }
        .accessibilityAction(.escape, cancel)
    }

    private var cancelButton: some View {
        Button("キャンセル", action: cancel).buttonStyle(ShinobiButtonStyle(kind: .secondary, height: 44))
    }
    private var confirmButton: some View {
        Button(actionTitle, role: .destructive, action: confirm)
            .buttonStyle(ShinobiButtonStyle(kind: .destructive, height: 44))
            .background(ShinobiStyle.dangerSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}
