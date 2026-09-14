import SwiftUI

struct OnboardingView: View {
    enum Mode { case firstLaunch, replay }

    let mode: Mode
    let finish: () -> Void
    @State private var page = 0
    @AccessibilityFocusState private var dialogueFocused: Bool

    private let pageCount = 4
    private var isLastPage: Bool { page == pageCount - 1 }
    private var isExplanation: Bool { page == 1 || page == 2 }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                ScrollView {
                    pageContent
                        .frame(minHeight: max(0, geometry.size.height - 122))
                }
                .id(page)
                .scrollBounceBehavior(.basedOnSize)
                Button(action: advance) {
                    Text(isLastPage ? (mode == .replay ? "閉じる" : "はじめる") : "つぎへ")
                }
                .buttonStyle(ShinobiButtonStyle(height: 52))
                .accessibilityIdentifier("onboarding.next")
                .padding(.top, 16).padding(.bottom, 10)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ShinobiStyle.background.ignoresSafeArea())
        .foregroundStyle(ShinobiStyle.text)
        .interactiveDismissDisabled()
        .task(id: page) { dialogueFocused = true }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule().fill(index == page ? ShinobiStyle.accent : ShinobiStyle.border)
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("カルマの案内")
            .accessibilityValue("\(page + 1) / \(pageCount) ページ")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if !isLastPage { page += 1 }
                case .decrement: if page > 0 { page -= 1 }
                @unknown default: break
                }
            }
            HStack {
                Spacer()
                if mode == .replay || !isLastPage {
                    Button(mode == .replay ? "閉じる" : "スキップ", action: finish)
                        .shinobiFont(15).foregroundStyle(ShinobiStyle.muted)
                        .frame(minWidth: 72, minHeight: 44, alignment: .trailing)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.dismiss")
                }
            }
        }.frame(height: 44)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExplanation {
                portrait(size: 200)
                    .frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 12)
                dialogue
                Spacer(minLength: 24)
                if page == 1 { ruleExample }
                else { unlockConditions }
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 12)
                portrait(size: 320)
                    .frame(maxWidth: .infinity).padding(.bottom, 6)
                dialogue
                Spacer(minLength: 28)
            }
        }
    }

    static let portraits = ["karma-onboarding-intro", "karma-onboarding-rules",
                            "karma-onboarding-unlock", "karma-onboarding-farewell"]

    private func portrait(size: CGFloat) -> some View {
        Image(Self.portraits[page])
            .resizable().scaledToFit().frame(width: size, height: size)
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .accessibilityHidden(true)
    }

    private var dialogue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カルマ").shinobiFont(11, relativeTo: .caption2)
                .tracking(2.2).foregroundStyle(ShinobiStyle.muted)
            Text(KarmaDialogue.catalog.onboardingLine(at: page))
                .shinobiFont(21, weight: .medium, relativeTo: .title3)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($dialogueFocused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var ruleExample: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("仕事に集中").shinobiFont(15, weight: .medium)
                    Spacer(minLength: 0)
                    Toggle("ルールの見本", isOn: .constant(true))
                        .labelsHidden().tint(ShinobiStyle.accentFill)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                exampleTime
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { exampleDays; Spacer(minLength: 0); exampleBadge }
                    VStack(alignment: .leading, spacing: 8) { exampleDays; exampleBadge }
                }
            }.card(padding: 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("ルールの見本。仕事に集中。月曜から金曜、9時から18時。3個のアプリをロック。")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { ruleFields }
                VStack(alignment: .leading, spacing: 12) { ruleFields }
            }.padding(.horizontal, 4)
        }
    }

    private var exampleTime: some View {
        Text("09:00 – 18:00").monospacedDigit().shinobiFont(22, weight: .medium, relativeTo: .title3)
    }

    private var exampleDays: some View {
        Text("月〜金 · 3個のアプリ").shinobiFont(13, relativeTo: .footnote)
            .foregroundStyle(ShinobiStyle.muted)
    }

    private var exampleBadge: some View { ShinobiBadge(title: "ロック時間中", symbol: "lock.fill") }

    private var ruleFields: some View {
        Group {
            ruleField("曜日", symbol: "calendar")
            ruleField("時間帯", symbol: "clock")
            ruleField("アプリ", symbol: "square.grid.2x2")
        }
    }

    private func ruleField(_ title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(ShinobiStyle.accentText).accessibilityHidden(true)
            Text(title).foregroundStyle(ShinobiStyle.subdued)
        }.shinobiFont(12, relativeTo: .caption)
    }

    private var unlockConditions: some View {
        VStack(alignment: .leading, spacing: 14) {
            condition(symbol: "checkmark", color: ShinobiStyle.accentText,
                      text: Text("広告を最後まで見ると、そのアプリだけ \(Text("5分間").foregroundStyle(ShinobiStyle.accentBright)) 使えます。"))
            condition(symbol: "xmark", color: ShinobiStyle.muted,
                      text: Text("途中で閉じると解除されません。"))
            condition(symbol: "eye", color: ShinobiStyle.danger,
                      text: Text("解除の前に、カルマがひとこと。"))
        }.padding(.horizontal, 2).padding(.vertical, 4)
    }

    private func condition(symbol: String, color: Color, text: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(color)
                .frame(width: 18).padding(.top, 2).accessibilityHidden(true)
            text.shinobiFont(15).lineSpacing(5).foregroundStyle(ShinobiStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func advance() {
        if isLastPage { finish() }
        else { page += 1 }
    }
}
