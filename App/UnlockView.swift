import SwiftUI
import FamilyControls
import ManagedSettings

struct UnlockView: View {
    @ObservedObject var model: LockModel
    let token: ApplicationToken
    @StateObject private var ads = RewardedAds()
    @Environment(\.dismiss) private var dismiss
    @State private var loadingTask: Task<Void, Never>?

    private var eligible: Bool {
        model.isAuthorized && model.state.applicationsRestrictedByRules().contains(token)
            && model.state.temporaryAccess?.isValid() != true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: ads.granted ? "lock.open" : "hourglass")
                        .font(.system(size: 46)).padding(.top, 24).accessibilityHidden(true)
                    Text(ads.granted ? "5分間、使えます。" : "ひと息ついて、\n5分だけ。")
                        .font(.largeTitle.bold())
                    Label(token).font(.title2)
                    if ads.granted {
                        Text("ホーム画面から対象アプリへ戻ってください。ルールの時間中なら、5分後に自動で再ロックします。")
                        if let access = model.state.temporaryAccess, access.token == token {
                            Text(timerInterval: Date.now...max(.now, access.deadline), countsDown: true)
                                .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                        }
                        Button("ホームに戻る") { dismiss() }.buttonStyle(.borderedProminent)
                    } else {
                        Text("広告を最後まで見ると、このアプリだけ5分間使えます。ほかのアプリのロックは続きます。")
                        if !eligible && !ads.busy {
                            Text(model.state.temporaryAccess?.isValid() == true
                                 ? "一時解除が終わってから、もう一度お試しください。"
                                 : "このアプリのロック時間は終了しました。")
                                .font(.subheadline)
                        }
                        Button {
                            loadingTask = Task {
                                await ads.show(eligible: { eligible }, reward: { try model.unlock(token) })
                            }
                        } label: {
                            HStack {
                                if ads.busy { ProgressView().tint(.white) }
                                Text(ads.busy ? "広告を準備しています" : "広告を見て5分使う")
                            }.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).disabled(ads.busy || !eligible)
                        Text("通信が必要です。途中で閉じた場合や、広告を表示できない場合は解除されません。")
                            .font(.footnote).foregroundStyle(ShinobiStyle.muted)
                    }
                    if let message = ads.message {
                        Label(message, systemImage: "info.circle").font(.subheadline).card()
                    }
                    if AdConfiguration.usesTestAds {
                        Text("開発版：Googleのテスト広告を表示します。")
                            .font(.caption).foregroundStyle(ShinobiStyle.muted)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .background(ShinobiStyle.paper).foregroundStyle(ShinobiStyle.ink)
            .navigationTitle("5分だけ使う").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { loadingTask?.cancel(); dismiss() }.disabled(ads.presenting)
                }
            }
            .interactiveDismissDisabled(ads.presenting)
            .onDisappear { if !ads.presenting { loadingTask?.cancel() } }
        }
    }
}
