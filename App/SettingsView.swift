import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: LockModel
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var showingOnboarding = false

    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            + " (" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") + ")"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ShinobiSection(title: "スクリーンタイム") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("利用許可").shinobiFont()
                                Spacer()
                                ShinobiBadge(title: model.isAuthorized ? "許可済み" : "許可が必要",
                                             symbol: model.isAuthorized ? "checkmark" : nil, accented: model.isAuthorized)
                            }
                            if !model.isAuthorized {
                                Button(model.authorizing ? "許可を確認しています" : "もう一度許可する") {
                                    Task { await model.authorize() }
                                }.buttonStyle(ShinobiButtonStyle()).disabled(model.authorizing)
                                if let message = model.authorizationMessage {
                                    Text(message).shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.danger)
                                }
                            }
                        }.card(padding: 16)
                    }
                    ShinobiSection(title: "カルマ") {
                        Button { showingOnboarding = true } label: {
                            HStack(spacing: 12) {
                                Image("karma-onboarding-intro")
                                    .resizable().scaledToFit().frame(width: 52, height: 52)
                                    .offset(y: 8).frame(width: 40, height: 40)
                                    .background(ShinobiStyle.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .accessibilityHidden(true)
                                Text("案内をもう一度見る").shinobiFont()
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: 16))
                                    .foregroundStyle(ShinobiStyle.subdued).accessibilityHidden(true)
                            }.card(padding: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("カルマの案内をもう一度見る")
                    }
                    ShinobiSection(title: "データとプライバシー") {
                        VStack(alignment: .leading, spacing: 0) {
                            Label("ルールとアプリの選択情報は、このiPhone内に保存します。", systemImage: "iphone")
                                .shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.secondary)
                                .padding(16)
                            // Preserve the SDK disclosure without implying all advertising data stays on device.
                            DisclosureGroup("広告で扱う情報") {
                                Text("広告を表示すると、Googleの広告SDKがIPアドレスや広告の操作情報などを扱います。選んだアプリやルールの情報は、広告SDKへ渡しません。")
                                    .shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
                                    .padding(.vertical, 8)
                            }.shinobiFont(13, relativeTo: .footnote).padding(.horizontal, 16).padding(.bottom, 14)
                            separator
                            Link(destination: URL(string: "https://policies.google.com/privacy?hl=ja")!) {
                                settingsRow("Googleのプライバシーポリシー", symbol: "arrow.up.forward.square")
                            }.foregroundStyle(ShinobiStyle.text)
                            if AdPrivacy.optionsRequired {
                                separator
                                Button {
                                    Task {
                                        do { try await AdPrivacy.showOptions() }
                                        catch { errorMessage = "広告のプライバシー設定を表示できませんでした。時間をおいてお試しください。" }
                                    }
                                } label: { settingsRow("広告のプライバシー設定", symbol: "chevron.right") }
                                    .buttonStyle(.plain)
                            }
                        }.card(padding: 0)
                    }
                    #if DEBUG
                    NavigationLink {
                        List(model.state.events.reversed()) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.kind)
                                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption).foregroundStyle(.secondary)
                            }.listRowBackground(ShinobiStyle.surface)
                        }
                        .scrollContentBackground(.hidden).background(ShinobiStyle.background)
                        .navigationTitle("開発用ログ").toolbar(.visible, for: .navigationBar)
                    } label: { Text("開発用ログ").shinobiFont(12, relativeTo: .caption).frame(minHeight: 44) }
                        .foregroundStyle(ShinobiStyle.subdued).frame(maxWidth: .infinity)
                    #endif
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
            }
            .shinobiScreen()
            .safeAreaInset(edge: .top, spacing: 0) {
                ShinobiHeader(title: "設定") { Color.clear.frame(height: 44) } trailing: {
                    Button("完了") { dismiss() }.fontWeight(.medium).frame(minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Text("忍びロック " + version).shinobiFont(12, relativeTo: .caption)
                    .foregroundStyle(ShinobiStyle.subdued).frame(maxWidth: .infinity)
                    .padding(.vertical, 16).background(ShinobiStyle.background)
            }
            .alert("確認してください", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView(mode: .replay) { showingOnboarding = false }
            }
        }
    }

    private var separator: some View { Divider().overlay(ShinobiStyle.border).padding(.horizontal, 16) }
    private func settingsRow(_ title: String, symbol: String, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(title).shinobiFont().multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.system(size: 16))
                .foregroundStyle(destructive ? ShinobiStyle.danger : ShinobiStyle.subdued).accessibilityHidden(true)
        }
        .foregroundStyle(destructive ? ShinobiStyle.danger : ShinobiStyle.text)
        .padding(16).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
    }
}
