import SwiftUI
import FamilyControls

struct RuleEditorView: View {
    @ObservedObject var model: LockModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: LockRule
    @State private var selection: FamilyActivitySelection
    @State private var showingPicker = false
    @State private var hasClosedPicker = false
    @State private var ruleAction: RuleActionRequest?
    @State private var completedRuleAction = false
    @State private var attemptedSave = false
    @State private var errorMessage: String?
    @State private var editingTime: TimeField?
    @FocusState private var nameFocused: Bool
    private let isNew: Bool

    private enum Field: Hashable { case name, days, time, apps }
    private enum TimeField: String, Identifiable {
        case start = "開始", end = "終了"
        var id: String { rawValue }
        var keyPath: WritableKeyPath<WeeklySchedule, Int> {
            self == .start ? \.startMinute : \.endMinute
        }
    }

    init(model: LockModel, rule: LockRule) {
        self.model = model
        _draft = State(initialValue: rule)
        var selection = FamilyActivitySelection(includeEntireCategory: true)
        selection.applicationTokens = rule.applications
        _selection = State(initialValue: selection)
        isNew = !model.state.rules.contains { $0.id == rule.id }
    }

    private var nameMessage: String? {
        guard attemptedSave || draft.name.count > 30 else { return nil }
        return (1...30).contains(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).count)
            ? nil : ProbeError.invalidName.errorDescription
    }
    private var dayMessage: String? {
        attemptedSave && draft.schedule.weekdays.isEmpty ? WeeklySchedule.ValidationError.weekdays.errorDescription : nil
    }
    private var timeMessage: String? {
        guard attemptedSave else { return nil }
        do { try draft.schedule.validate(); return nil }
        catch WeeklySchedule.ValidationError.weekdays { return nil }
        catch { return error.localizedDescription }
    }
    private var selectionMessage: String? {
        if selection.applicationTokens.count > LockRule.maximumApplications {
            return ProbeError.tooManyApplications.errorDescription
        }
        if (hasClosedPicker || attemptedSave) && selection.applicationTokens.isEmpty {
            return "アプリが選択されていません。カテゴリを開いて、アプリを1つ以上選んでください。"
        }
        var proposed = draft
        proposed.applications = selection.applicationTokens
        let rules = model.state.rules.filter { $0.id != draft.id } + [proposed]
        if RuleEvaluator.exceedsApplicationLimit(from: rules.map(\.scheduledApplications), maximum: LockRule.maximumApplications) {
            return ProbeError.tooManyOverlappingApplications.errorDescription
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        nameField.id(Field.name)
                        daysField.id(Field.days)
                        timeField.id(Field.time)
                        appsField.id(Field.apps)
                        Toggle(isNew ? "保存したらすぐ有効にする" : "有効", isOn: $draft.isEnabled)
                            .shinobiFont().tint(ShinobiStyle.accentFill)
                            .frame(minHeight: 44)
                            .disabled(!model.isAuthorized && !draft.isEnabled)
                        if !isNew {
                            Button(role: .destructive) {
                                nameFocused = false
                                guard let original = model.state.rules.first(where: { $0.id == draft.id }) else { return }
                                ruleAction = .delete(original: original)
                            } label: { Label("このルールを削除", systemImage: "trash") }
                                .buttonStyle(ShinobiButtonStyle(kind: .destructive)).padding(.top, 8)
                        }
                    }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .shinobiScreen()
                .safeAreaInset(edge: .top, spacing: 0) {
                    ShinobiHeader(title: isNew ? "新しいルール" : "ルールを編集") {
                        Button("キャンセル") { dismiss() }
                            .foregroundStyle(ShinobiStyle.secondary).frame(minHeight: 44)
                    } trailing: {
                        Button("保存") {
                            attemptedSave = true
                            let field: Field? = nameMessage != nil ? .name : dayMessage != nil ? .days
                                : timeMessage != nil ? .time : selectionMessage != nil ? .apps : nil
                            if let field {
                                nameFocused = field == .name
                                withAnimation { scroll.scrollTo(field, anchor: .top) }
                            } else { save() }
                        }
                        .fontWeight(.medium).frame(minHeight: 44)
                        .disabled(model.working || selection.applicationTokens.isEmpty || selectionMessage != nil)
                    }
                }
                .onChange(of: nameFocused) { _, focused in
                    if focused { withAnimation { scroll.scrollTo(Field.name, anchor: .top) } }
                }
            }
            .sheet(item: $ruleAction, onDismiss: {
                if completedRuleAction { dismiss() }
            }) { request in
                RuleActionView(model: model, request: request) { completedRuleAction = true }
            }
            .familyActivityPicker(
                headerText: "ロックするアプリを選んでください。カテゴリを選ぶと、中のアプリをまとめて選べます。",
                footerText: "Webサイトは対象外です。アプリを1〜\(LockRule.maximumApplications)個選んでください。後から入れたアプリは選び直して追加してください。",
                isPresented: $showingPicker, selection: $selection
            )
            .onChange(of: showingPicker) { _, presented in
                if !presented { hasClosedPicker = true }
            }
            .sheet(item: $editingTime) { field in
                VStack(spacing: 16) {
                    HStack {
                        Text(field.rawValue + "時刻").shinobiFont(17, weight: .medium)
                        Spacer()
                        Button("完了") { editingTime = nil }.frame(minHeight: 44)
                    }
                    DatePicker(field.rawValue, selection: timeBinding(field.keyPath), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden()
                }.padding(20).presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible).presentationBackground(ShinobiStyle.surface)
            }
            .alert("保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var nameField: some View {
        ShinobiSection(title: "ルール名") {
            HStack(spacing: 8) {
                TextField("たとえば「仕事に集中」", text: $draft.name)
                    .focused($nameFocused).submitLabel(.done).accessibilityLabel("ルール名")
                    .onSubmit { nameFocused = false }
                Text("\(draft.name.count)/30").monospacedDigit().shinobiFont(12, relativeTo: .caption)
                    .foregroundStyle(draft.name.count > 30 ? ShinobiStyle.danger : ShinobiStyle.subdued)
                    .fixedSize().accessibilityLabel("\(draft.name.count)文字、30文字まで")
            }
            .shinobiFont().padding(.horizontal, 14).frame(minHeight: 48)
            .background(ShinobiStyle.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                nameMessage != nil ? ShinobiStyle.dangerBorder : nameFocused ? ShinobiStyle.accent : ShinobiStyle.border))
            fieldError(nameMessage)
        }
    }

    private var daysField: some View {
        ShinobiSection(title: "曜日") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                    count: dynamicTypeSize.isAccessibilitySize ? 4 : 7), spacing: 6) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    let selected = draft.schedule.weekdays.contains(day)
                    Button {
                        if selected { draft.schedule.weekdays.remove(day) }
                        else { draft.schedule.weekdays.insert(day) }
                    } label: {
                        Text(LockRule.dayName(day)).shinobiFont(14, weight: .medium)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? ShinobiStyle.accentBright : ShinobiStyle.muted)
                            .background(selected ? ShinobiStyle.accentSurface : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(selected ? ShinobiStyle.accentBorder : ShinobiStyle.border))
                    }.buttonStyle(.plain)
                        .accessibilityLabel(LockRule.dayName(day) + "曜日")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            HStack(spacing: 12) {
                dayPreset("平日", days: Set(2...6))
                dayPreset("毎日", days: Set(1...7))
                dayPreset("週末", days: Set([1, 7]))
            }
            fieldError(dayMessage)
        }
    }

    private func dayPreset(_ title: String, days: Set<Int>) -> some View {
        Button(title) { draft.schedule.weekdays = days }
            .buttonStyle(.plain).shinobiFont(12, relativeTo: .caption)
            .foregroundStyle(ShinobiStyle.accentText).frame(minWidth: 44, minHeight: 32)
            .accessibilityLabel(title + "をまとめて選択")
    }

    private var timeField: some View {
        ShinobiSection(title: "時間帯") {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { timeButton(.start); timeButton(.end) }
            } else {
                HStack(spacing: 10) {
                    timeButton(.start)
                    Image(systemName: "arrow.right").foregroundStyle(ShinobiStyle.subdued).accessibilityHidden(true)
                    timeButton(.end)
                }
            }
            if let timeMessage { fieldError(timeMessage) }
            else {
                Text("日付をまたぐときは2つに分けてください。")
                    .shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.subdued)
            }
        }
    }

    private func timeButton(_ field: TimeField) -> some View {
        Button {
            nameFocused = false
            editingTime = field
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.rawValue).shinobiFont(11, relativeTo: .caption).foregroundStyle(ShinobiStyle.subdued)
                Text(LockRule.timeText(draft.schedule[keyPath: field.keyPath]))
                    .monospacedDigit().shinobiFont(20, weight: .medium, relativeTo: .title3)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).padding(.horizontal, 14)
            .background(ShinobiStyle.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(timeMessage == nil ? ShinobiStyle.border : ShinobiStyle.dangerBorder))
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
    }

    private var appsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selection.applicationTokens.isEmpty ? "ロックするアプリ" : "ロックするアプリ · \(selection.applicationTokens.count)個")
                    .shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.muted)
                Spacer(minLength: 8)
                if !selection.applicationTokens.isEmpty {
                    Button("選び直す", action: openPicker).buttonStyle(.plain)
                        .shinobiFont(13, relativeTo: .footnote).frame(minHeight: 44).disabled(!model.isAuthorized)
                }
            }
            if selection.applicationTokens.isEmpty {
                Button(action: openPicker) {
                    Label("アプリを選ぶ", systemImage: "square.grid.2x2")
                }.buttonStyle(ShinobiButtonStyle()).disabled(!model.isAuthorized)
                if selectionMessage == nil {
                    Text("まだ選んでいません。").shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.subdued)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        Label(token).shinobiFont().frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, 16)
                            .overlay(alignment: .bottom) { Divider().overlay(ShinobiStyle.border).padding(.horizontal, 16) }
                    }
                }.card(padding: 0)
            }
            fieldError(selectionMessage)
            if !model.isAuthorized {
                fieldError("アプリを選ぶには、スクリーンタイムの利用を許可してください。")
            }
            if !selection.webDomainTokens.isEmpty {
                Text("Webサイトは対象外です。選んだアプリだけを保存します。")
                    .shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.muted)
            }
        }
    }

    @ViewBuilder private func fieldError(_ message: String?) -> some View {
        if let message {
            Text(message).shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openPicker() {
        nameFocused = false
        var appsOnly = FamilyActivitySelection(includeEntireCategory: true)
        appsOnly.applicationTokens = selection.applicationTokens
        selection = appsOnly
        showingPicker = true
    }

    private func save() {
        do {
            draft.applications = selection.applicationTokens
            if let original = model.state.rules.first(where: { $0.id == draft.id }),
               original.isEnabled && !draft.isEnabled {
                try draft.validate()
                nameFocused = false
                ruleAction = .pause(original: original, updated: draft)
                return
            }
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
