import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: LockModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingPause = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("スクリーンタイム") {
                    LabeledContent("利用許可", value: model.isAuthorized ? "許可済み" : "許可が必要")
                    if !model.isAuthorized {
                        Button("もう一度許可する") { Task { await model.authorize() } }
                    }
                    Text("許可の変更は、設定アプリの「スクリーンタイム」から行えます。")
                        .font(.footnote)
                }
                Section("データとプライバシー") {
                    Text("ルールとアプリの選択情報は、このiPhone内に保存します。アカウント登録は必要ありません。")
                    Text("広告を表示すると、Googleの広告SDKがIPアドレスや広告の操作情報などを扱います。選んだアプリやルールの情報を、広告SDKへ渡すことはありません。")
                    Link("Googleのプライバシーポリシー", destination: URL(string: "https://policies.google.com/privacy?hl=ja")!)
                    if AdPrivacy.optionsRequired {
                        Button("広告のプライバシー設定") {
                            Task {
                                do { try await AdPrivacy.showOptions() }
                                catch { errorMessage = "広告のプライバシー設定を表示できませんでした。時間をおいてお試しください。" }
                            }
                        }
                    }
                }
                Section {
                    Button("すべてのルールを休止", role: .destructive) { confirmingPause = true }
                } footer: { Text("すべてのロックを解除します。保存したルールは、あとから個別に有効にできます。") }
                Section {
                    LabeledContent("バージョン", value: (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") + " (" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") + ")")
                    #if DEBUG
                    NavigationLink("開発用ログ") {
                        List(model.state.events.reversed()) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.kind)
                                Text(event.timestamp.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
                            }
                        }.navigationTitle("開発用ログ")
                    }
                    #endif
                }
            }
            .scrollContentBackground(.hidden).background(ShinobiStyle.paper)
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
            .confirmationDialog("すべてのルールを休止しますか？", isPresented: $confirmingPause, titleVisibility: .visible) {
                Button("休止してロックを解除", role: .destructive) {
                    do { try model.pauseAll() }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            .alert("確認してください", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
