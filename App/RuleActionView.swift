import SwiftUI

struct RuleActionRequest: Identifiable {
    let id = UUID()
    let original: LockRule
    let updated: LockRule?

    static func pause(original: LockRule, updated: LockRule) -> Self {
        Self(original: original, updated: updated)
    }

    static func delete(original: LockRule) -> Self {
        Self(original: original, updated: nil)
    }

    var isPause: Bool { updated != nil }
    var displayedRule: LockRule { updated ?? original }
    var verb: String { isPause ? "休止" : "削除" }
    var context: KarmaContext { isPause ? .pauseRule : .deleteRule }
    var hasOtherEdits: Bool {
        guard var comparison = updated else { return false }
        comparison.isEnabled = original.isEnabled
        return comparison != original
    }
}

struct RuleActionView: View {
    @ObservedObject var model: LockModel
    let request: RuleActionRequest
    var onCompleted: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ads = RewardedAds(
        ineligibleMessage: "ルールが変更されています。画面を閉じて、内容を確認してください。",
        incompleteMessage: "広告の視聴が完了していないため、ルールは変更していません。"
    )
    @State private var encounter: KarmaEncounter?
    @State private var loadingTask: Task<Void, Never>?
    @State private var completed = false

    private var eligible: Bool { model.canPerform(request) }

    var body: some View {
        NavigationStack {
            Group {
                if let encounter {
                    KarmaRoomView(encounter: encounter, context: request.context,
                                  continueToAd: showAd, stayLocked: { dismiss() })
                        .id(encounter.id)
                } else {
                    confirmation
                }
            }
        }
        .interactiveDismissDisabled(ads.presenting || encounter != nil)
        .onDisappear { if !ads.presenting { loadingTask?.cancel() } }
        .onChange(of: ads.busy) { _, busy in
            // Let the ad dismiss before closing its presenting sheet or the editor.
            guard !busy, ads.granted, !completed else { return }
            completed = true
            onCompleted()
            dismiss()
        }
    }

    private var confirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("このルールを\(request.verb)しますか？")
                    .shinobiFont(27, weight: .medium, relativeTo: .title)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(request.displayedRule.name).shinobiFont(18, weight: .medium, relativeTo: .headline)
                    Text(request.displayedRule.dayText + " · " + request.displayedRule.timeText)
                        .shinobiFont(14).foregroundStyle(ShinobiStyle.secondary)
                    Text("\(request.displayedRule.applications.count)個のアプリ")
                        .shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
                }.card()
                Text(request.isPause
                     ? "このルールによるロックを止めます。再び有効にするまで休止が続きます。"
                     : "このルールを削除します。元に戻せません。")
                    .shinobiFont().foregroundStyle(ShinobiStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("広告の視聴を完了すると\(request.verb)します。途中でやめた場合、ルールは変更しません。")
                    .shinobiFont(14).foregroundStyle(ShinobiStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if request.hasOtherEdits {
                    Text("編集した内容は、休止と同時に保存します。")
                        .shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
                }
                if !eligible && !ads.busy && !ads.granted {
                    ShinobiMessage(text: "ルールが変更されています。画面を閉じて、内容を確認してください。")
                } else if let message = ads.message {
                    ShinobiMessage(text: message, isError: ads.failed)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 24)
        }
        .shinobiScreen()
        .safeAreaInset(edge: .top, spacing: 0) {
            ShinobiHeader(title: "ルールの\(request.verb)") {
                Button("閉じる") { loadingTask?.cancel(); dismiss() }
                    .foregroundStyle(ShinobiStyle.secondary).frame(minHeight: 44).disabled(ads.presenting)
            } trailing: { Color.clear.frame(height: 44) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                Button {
                    guard eligible, !ads.busy else { return }
                    encounter = KarmaDialogue.next(context: request.context)
                } label: {
                    HStack(spacing: 8) {
                        if ads.busy { ProgressView() }
                        Text(ads.busy ? "広告を準備しています" : "広告を見て\(request.verb)する")
                    }
                }.buttonStyle(ShinobiButtonStyle(height: 52)).disabled(ads.busy || !eligible)
                Button("やめておく") { loadingTask?.cancel(); dismiss() }
                    .buttonStyle(ShinobiButtonStyle(kind: .secondary, height: 52)).disabled(ads.presenting)
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
                .background(ShinobiStyle.background)
        }
    }

    private func showAd() {
        encounter = nil
        loadingTask = Task {
            await ads.show(eligible: { eligible }, reward: { try model.performRewardedAction(request) })
        }
    }
}
