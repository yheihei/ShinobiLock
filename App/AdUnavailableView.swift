import SwiftUI

struct AdUnavailableView: View {
    let encounter: KarmaEncounter
    let secondsRemaining: Int
    let actionTitle: String
    let detail: String
    let eligible: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700 || dynamicTypeSize.isAccessibilitySize
            ScrollView {
                VStack(spacing: compact ? 14 : 22) {
                    Text("カルマの間")
                        .shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.muted)
                    Image(encounter.portrait.rawValue)
                        .resizable().scaledToFit()
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 130 : compact ? 190 : 250)
                        .accessibilityLabel(encounter.portrait.description)
                    Text(encounter.line)
                        .shinobiFont(compact ? 19 : 21, weight: .medium, relativeTo: .title3)
                        .lineSpacing(7).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 8) {
                        Text("広告を表示できませんでした")
                            .shinobiFont(14, weight: .medium)
                        Text(detail)
                            .shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    if !eligible {
                        ShinobiMessage(text: "ロックやルールの状態が変わりました。いったん閉じて確認してください。")
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 20)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 12) {
                    Button("やめておく", action: cancel)
                        .buttonStyle(ShinobiButtonStyle(height: 50))
                        .accessibilityHint("変更せずに閉じます")
                    Button(action: confirm) {
                        Text(secondsRemaining > 0 ? "あと\(secondsRemaining)秒" : actionTitle)
                            .monospacedDigit()
                    }
                    .buttonStyle(ShinobiButtonStyle(kind: .secondary, height: 50))
                    .disabled(secondsRemaining > 0 || !eligible)
                    .accessibilityLabel(secondsRemaining > 0 ? "待機時間、残り\(secondsRemaining)秒" : actionTitle)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
                .background(ShinobiStyle.background.opacity(0.95))
            }
            .background {
                Image("karma-realm-bg").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped().ignoresSafeArea().accessibilityHidden(true)
            }
        }
        .background(ShinobiStyle.background).foregroundStyle(ShinobiStyle.text)
        .toolbar(.hidden, for: .navigationBar)
    }
}
