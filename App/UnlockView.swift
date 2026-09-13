import SwiftUI
import FamilyControls
import ManagedSettings

struct UnlockView: View {
    @ObservedObject var model: LockModel
    let token: ApplicationToken
    @StateObject private var ads = RewardedAds()
    @Environment(\.dismiss) private var dismiss
    @State private var loadingTask: Task<Void, Never>?
    @State private var karmaEncounter: KarmaEncounter?

    private var activeAccess: TemporaryAccess? {
        guard let access = model.state.temporaryAccess, access.token == token, access.isValid() else { return nil }
        return access
    }
    private var eligible: Bool {
        model.isAuthorized && model.state.applicationsRestrictedByRules().contains(token)
            && model.state.temporaryAccess?.isValid() != true
    }

    var body: some View {
        NavigationStack {
            Group {
                if let encounter = karmaEncounter {
                    KarmaRoomView(encounter: encounter, continueToAd: showAd, stayLocked: { dismiss() })
                        .id(encounter.id)
                } else {
                    unlockDetails
                }
            }
        }
        .interactiveDismissDisabled(ads.presenting || karmaEncounter != nil)
        .onDisappear { if !ads.presenting { loadingTask?.cancel() } }
    }

    private var unlockDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introduction
                if ads.granted {
                    grantedCard
                    if activeAccess != nil {
                        Label("ホーム画面から対象アプリを開いてください。", systemImage: "arrow.up.forward.square")
                            .shinobiFont().foregroundStyle(ShinobiStyle.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("解除するアプリ").shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.muted)
                        Label(token).shinobiFont(17, weight: .medium)
                    }.card(padding: 16)
                    VStack(alignment: .leading, spacing: 14) {
                        condition("広告を最後まで見ると、このアプリだけ5分間使えます。", symbol: "checkmark", accented: true)
                        condition("途中で閉じると解除されません。", symbol: "xmark", accented: false)
                    }.padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 24)
        }
        .shinobiScreen()
        .safeAreaInset(edge: .top, spacing: 0) {
            ShinobiHeader(title: "5分だけ使う") {
                if !ads.granted {
                    Button("閉じる") { loadingTask?.cancel(); dismiss() }
                        .foregroundStyle(ShinobiStyle.secondary).frame(minHeight: 44).disabled(ads.presenting)
                }
            } trailing: { Color.clear.frame(height: 44) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
                .background(ShinobiStyle.background)
        }
    }

    private func showAd() {
        karmaEncounter = nil
        loadingTask = Task {
            await ads.show(eligible: { eligible }, reward: { try model.unlock(token) })
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: ads.granted ? "lock.open" : "hourglass")
                .font(.system(size: 28)).foregroundStyle(ShinobiStyle.accentText)
                .frame(width: 56, height: 56)
                .background(ShinobiStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(ads.granted ? ShinobiStyle.accentBorder : ShinobiStyle.border))
                .shadow(color: ads.granted ? ShinobiStyle.accent.opacity(0.22) : .clear, radius: 12)
                .accessibilityHidden(true)
            Text(ads.granted ? (activeAccess == nil ? "一時解除が終了しました。" : "5分間、使えます。") : "ひと息ついて、\n5分だけ。")
                .shinobiFont(29, weight: .medium, relativeTo: .title).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var grantedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(token).shinobiFont(15, weight: .medium)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let access = activeAccess {
                    Text(timerInterval: Date.now...max(.now, access.deadline), countsDown: true)
                        .monospacedDigit().shinobiFont(64, weight: .medium, relativeTo: .largeTitle)
                        .minimumScaleFactor(0.6).foregroundStyle(ShinobiStyle.accentBright)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("一時解除の残り時間")
                } else {
                    Text("0:00").monospacedDigit().shinobiFont(64, weight: .medium, relativeTo: .largeTitle)
                        .minimumScaleFactor(0.6).foregroundStyle(ShinobiStyle.accentBright)
                }
                Text("残り").shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
                Spacer(minLength: 0)
            }
            if let access = activeAccess {
                ProgressView(timerInterval: access.window.startedAt...access.deadline, countsDown: true)
                    .labelsHidden().tint(ShinobiStyle.accentFill)
                    .accessibilityHidden(true)
            } else {
                ProgressView(value: 0).tint(ShinobiStyle.accentFill).accessibilityHidden(true)
                Text("現在のルールに合わせてロックします。")
                    .shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
            }
        }.card()
    }

    private func condition(_ text: String, symbol: String, accented: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18))
                .foregroundStyle(accented ? ShinobiStyle.accentText : ShinobiStyle.muted)
                .frame(width: 18).padding(.top, 2).accessibilityHidden(true)
            Text(text).shinobiFont().foregroundStyle(accented ? ShinobiStyle.text : ShinobiStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            if ads.granted {
                Button("忍びロックのホームへ") { dismiss() }
                    .buttonStyle(ShinobiButtonStyle(kind: .secondary, height: 52))
            } else {
                if !eligible && !ads.busy {
                    if !model.isAuthorized {
                        ShinobiMessage(text: "スクリーンタイムの許可を確認してください。")
                    } else if let access = model.state.temporaryAccess, access.isValid() {
                        ShinobiMessage(text: "一時解除が終わってから、もう一度お試しください。")
                        HStack {
                            Text("一時解除の残り時間").shinobiFont(13, relativeTo: .footnote)
                            Text(timerInterval: Date.now...max(.now, access.deadline), countsDown: true)
                                .monospacedDigit().frame(width: 60)
                        }.foregroundStyle(ShinobiStyle.muted)
                    } else {
                        ShinobiMessage(text: "このアプリのロック時間は終了しました。そのまま使えます。")
                    }
                } else if let message = ads.message {
                    ShinobiMessage(text: message, isError: ads.failed)
                }
                Button {
                    guard eligible, !ads.busy else { return }
                    karmaEncounter = KarmaDialogue.next()
                } label: {
                    HStack(spacing: 8) {
                        if ads.busy { ProgressView() }
                        else { Image(systemName: ads.failed ? "arrow.clockwise" : "play.circle") }
                        Text(ads.busy ? "広告を準備しています" : ads.failed ? "もう一度試す" : "広告を見て5分使う")
                    }
                }.buttonStyle(ShinobiButtonStyle(height: 52)).disabled(ads.busy || !eligible)
            }
            if AdConfiguration.usesTestAds {
                Text("開発版：Googleのテスト広告を表示します。")
                    .shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.subdued)
            }
        }
    }
}
