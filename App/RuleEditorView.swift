import SwiftUI
import FamilyControls

struct RuleEditorView: View {
    @ObservedObject var model: LockModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LockRule
    @State private var selection: FamilyActivitySelection
    @State private var showingPicker = false
    @State private var hasClosedPicker = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?
    private let isNew: Bool

    private var selectionMessage: String? {
        if selection.applicationTokens.count > LockRule.maximumApplications {
            return ProbeError.tooManyApplications.errorDescription
        }
        if hasClosedPicker && selection.applicationTokens.isEmpty {
            return "アプリが選択されていません。カテゴリを開いて、アプリを1つ以上選んでください。"
        }
        var proposed = draft
        proposed.applications = selection.applicationTokens
        let rules = model.state.rules.filter { $0.id != draft.id } + [proposed]
        if RuleEvaluator.exceedsApplicationLimit(from: rules.map(\.scheduledApplications),
                                                 maximum: LockRule.maximumApplications) {
            return ProbeError.tooManyOverlappingApplications.errorDescription
        }
        return nil
    }

    init(model: LockModel, rule: LockRule) {
        self.model = model
        _draft = State(initialValue: rule)
        var selection = FamilyActivitySelection(includeEntireCategory: true)
        selection.applicationTokens = rule.applications
        _selection = State(initialValue: selection)
        isNew = !model.state.rules.contains { $0.id == rule.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：仕事に集中", text: $draft.name)
                        .accessibilityLabel("ルール名").submitLabel(.done)
                } header: { Text("ルール名") } footer: { Text("1〜30文字で入力してください。") }
                Section("曜日") {
                    HStack(spacing: 2) {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            Button {
                                if draft.schedule.weekdays.contains(day) { draft.schedule.weekdays.remove(day) }
                                else { draft.schedule.weekdays.insert(day) }
                            } label: {
                                Text(LockRule.dayName(day)).font(.body.bold())
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(draft.schedule.weekdays.contains(day) ? Color.white : ShinobiStyle.ink)
                                    .background(draft.schedule.weekdays.contains(day) ? ShinobiStyle.ink : ShinobiStyle.paper, in: Capsule())
                            }.buttonStyle(.plain)
                                .accessibilityLabel(LockRule.dayName(day) + "曜日")
                                .accessibilityAddTraits(draft.schedule.weekdays.contains(day) ? .isSelected : [])
                        }
                    }
                }
                Section {
                    DatePicker("開始", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                } header: { Text("ロックする時間") } footer: {
                    Text("終了時刻は開始時刻より後に設定してください。日付をまたぐ場合はルールを分けてください。")
                }
                Section {
                    Button(action: openPicker) {
                        HStack {
                            Label(hasClosedPicker && selection.applicationTokens.isEmpty ? "アプリを選び直す" : "アプリを選ぶ",
                                  systemImage: "apps.iphone")
                            Spacer()
                            Text("\(selection.applicationTokens.count)個")
                            Image(systemName: "chevron.right").font(.caption)
                        }
                    }.disabled(!model.isAuthorized)
                    if !selection.applicationTokens.isEmpty {
                        DisclosureGroup("ロックするアプリを確認") {
                            ForEach(Array(selection.applicationTokens), id: \.self) { token in
                                Label(token)
                            }
                        }
                    }
                    if let selectionMessage {
                        Label(selectionMessage, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    if !selection.webDomainTokens.isEmpty {
                        Label("Webサイトは対象外です。選んだアプリだけを保存します。", systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(ShinobiStyle.muted)
                    }
                } header: { Text("対象アプリ") } footer: {
                    Text("アプリを1〜\(LockRule.maximumApplications)個選んでください。カテゴリからまとめて選べます。後からインストールしたアプリは、もう一度選んで追加してください。")
                }
                Section {
                    Toggle("このルールを有効にする", isOn: $draft.isEnabled)
                        .disabled(!model.isAuthorized && !draft.isEnabled)
                }
                if !isNew {
                    Section {
                        Button("ルールを削除", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(ShinobiStyle.paper)
            .navigationTitle(isNew ? "ルールをつくる" : "ルールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).bold()
                        .disabled(model.working || selection.applicationTokens.isEmpty || selectionMessage != nil)
                }
            }
            .familyActivityPicker(
                headerText: "ロックするアプリを選んでください。カテゴリを選ぶと、中のアプリをまとめて選べます。",
                footerText: "Webサイトはロックの対象外です。アプリを1〜\(LockRule.maximumApplications)個選んでください。",
                isPresented: $showingPicker, selection: $selection
            )
            .onChange(of: showingPicker) { _, isPresented in
                if !isPresented { hasClosedPicker = true }
            }
            .confirmationDialog("このルールを削除しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    do { try model.delete(draft.id); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
            } message: { Text("ほかのルールによるロックは続きます。") }
            .alert("保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func openPicker() {
        // Reopen the saved app snapshot, so categories only act as bulk selection.
        var appsOnly = FamilyActivitySelection(includeEntireCategory: true)
        appsOnly.applicationTokens = selection.applicationTokens
        selection = appsOnly
        showingPicker = true
    }

    private func save() {
        guard !selection.applicationTokens.isEmpty else { return }
        do {
            draft.applications = selection.applicationTokens
            try model.save(draft)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<WeeklySchedule, Int>) -> Binding<Date> {
        Binding(get: {
            let minutes = draft.schedule[keyPath: keyPath]
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft.schedule[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }
}
