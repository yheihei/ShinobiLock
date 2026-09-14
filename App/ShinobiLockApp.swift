import SwiftUI
import FamilyControls
import ManagedSettings

@main
struct ShinobiLockApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(ShinobiStyle.accentText)
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }
}

struct HomeView: View {
    @StateObject private var model = LockModel()
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingRule: LockRule?
    @State private var showingSettings = false
    @State private var unlockTarget: UnlockTarget?
    @State private var ruleAction: RuleActionRequest?
    @ScaledMetric(relativeTo: .title2) private var countdownWidth: CGFloat = 80

    var body: some View {
        Group {
            if onboardingCompleted {
                home
            } else {
                OnboardingView(mode: .firstLaunch) {
                    onboardingCompleted = true
                }
            }
        }
        .task { await AdPrivacy.shared.refreshAtLaunch() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            model.synchronize()
            presentPendingTarget()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard !Task.isCancelled else { return }
                model.refresh()
            }
        }
        .onChange(of: model.state.pendingUnlockRequest?.id) { _, requestID in
            if requestID != nil { presentPendingTarget() }
        }
    }

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.isAuthorized {
                        welcome
                        permissionCard
                    } else {
                        statusCard
                        if let access = model.state.temporaryAccess, access.isValid() {
                            accessCard(access)
                        }
                    }
                    if model.state.rules.isEmpty {
                        if model.isAuthorized { emptyGuide }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text("時間帯ルール").shinobiFont(13, relativeTo: .footnote)
                                .foregroundStyle(ShinobiStyle.muted)
                            Spacer(minLength: 8)
                            Text("\(model.state.rules.count)件 · タップで編集")
                                .shinobiFont(12, relativeTo: .caption).foregroundStyle(ShinobiStyle.subdued)
                        }.padding(.top, 6)
                        ForEach(model.state.rules) { rule in
                            RuleCard(rule: rule, isAuthorized: model.isAuthorized, working: model.working,
                                     edit: { editingRule = rule }, setEnabled: { value in
                                var updated = rule
                                updated.isEnabled = value
                                if value {
                                    model.handle { try model.save(updated) }
                                } else {
                                    ruleAction = .pause(original: rule, updated: updated)
                                }
                            })
                        }
                    }
                    Button { editingRule = .newDraft } label: {
                        Label("ルールをつくる", systemImage: "plus")
                    }
                    .buttonStyle(ShinobiButtonStyle())
                    .disabled(!model.isAuthorized || model.working)
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
            }
            .shinobiScreen()
            .safeAreaInset(edge: .top, spacing: 0) {
                ShinobiHeader(title: "カルマロック") { Color.clear.frame(height: 44) } trailing: {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape").font(.system(size: 20))
                            .frame(width: 36, height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ShinobiStyle.border))
                            .frame(width: 44, height: 44)
                    }.foregroundStyle(ShinobiStyle.secondary).accessibilityLabel("設定")
                }
            }
            .sheet(item: $editingRule, onDismiss: presentPendingTarget) { RuleEditorView(model: model, rule: $0) }
            .sheet(item: $unlockTarget) { UnlockView(model: model, token: $0.token) }
            .sheet(item: $ruleAction) { RuleActionView(model: model, request: $0) }
            .sheet(isPresented: $showingSettings, onDismiss: presentPendingTarget) { SettingsView(model: model) }
            .alert("確認してください", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
            .onAppear(perform: presentPendingTarget)
        }
    }

    private func presentPendingTarget() {
        guard onboardingCompleted, scenePhase == .active, model.isAuthorized, !model.working,
              editingRule == nil, !showingSettings, unlockTarget == nil, ruleAction == nil,
              model.state.pendingUnlockRequest != nil else { return }
        model.handle {
            if let token = try model.consumeUnlockRequest() {
                unlockTarget = UnlockTarget(token: token)
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(ShinobiStyle.accent).frame(width: 24, height: 2).accessibilityHidden(true)
            Text("大切な時間を、\n自分の手に。")
                .shinobiFont(29, weight: .medium, relativeTo: .title).lineSpacing(3)
        }.padding(.horizontal, 2).padding(.top, 24).padding(.bottom, 8)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(model.lockedApplications.isEmpty ? ShinobiStyle.disabled : ShinobiStyle.accent)
                .frame(width: 24, height: 2).accessibilityHidden(true)
            Text(statusTitle).shinobiFont(25, weight: .medium, relativeTo: .title2)
                .fixedSize(horizontal: false, vertical: true)
            if let statusDetail {
                Text(statusDetail).shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.muted)
            }
        }.card()
    }

    private var statusTitle: String {
        if model.state.rules.isEmpty { return "ルールはまだ\nありません。" }
        if !model.lockedApplications.isEmpty { return "\(model.lockedApplications.count)個のアプリを\nロックしています。" }
        return "いまはロック\nしていません。"
    }

    private var statusDetail: String? {
        let enabled = model.state.rules.filter(\.isEnabled)
        let active = enabled.filter { $0.schedule.contains(.now) }
        if active.count == 1, let rule = active.first, !model.lockedApplications.isEmpty {
            return rule.name + " · " + LockRule.timeText(rule.schedule.endMinute) + " まで"
        }
        if let next = enabled.compactMap({ $0.schedule.nextBoundary(after: .now) }).min() {
            // A boundary may change only part of an overlapping set; don't promise a full unlock.
            return "次の切り替え " + next.formatted(.dateTime.weekday().hour().minute())
        }
        return model.state.rules.isEmpty ? nil : "すべてのルールを休止しています。"
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("スクリーンタイムの許可が必要です", systemImage: "hourglass")
                .shinobiFont(15, weight: .medium)
            Button {
                Task { await model.authorize() }
            } label: {
                HStack(spacing: 8) {
                    if model.authorizing { ProgressView() }
                    Text(model.authorizing ? "許可を確認しています" : "スクリーンタイムを許可する")
                }
            }.buttonStyle(ShinobiButtonStyle()).disabled(model.authorizing)
            if let message = model.authorizationMessage {
                Text(message).shinobiFont(13, relativeTo: .footnote).foregroundStyle(ShinobiStyle.danger)
            }
        }.card()
    }

    private var emptyGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最初のルールをつくりましょう").shinobiFont(19, weight: .medium, relativeTo: .headline)
            guideStep("曜日を選ぶ", symbol: "calendar")
            guideStep("時間帯を決める", symbol: "clock")
            guideStep("ロックするアプリを選ぶ", symbol: "square.grid.2x2")
        }.padding(.horizontal, 2).padding(.top, 20).padding(.bottom, 4)
    }

    private func guideStep(_ text: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17))
                .foregroundStyle(ShinobiStyle.accentText).frame(width: 32, height: 32)
                .background(ShinobiStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(text).shinobiFont()
        }
    }

    private func accessCard(_ access: TemporaryAccess) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Label(access.token).shinobiFont(15, weight: .medium)
                ShinobiBadge(title: "一時解除中")
                countdown(access)
            }
            VStack(alignment: .leading, spacing: 10) {
                Label(access.token).shinobiFont(15, weight: .medium)
                HStack { ShinobiBadge(title: "一時解除中"); Spacer(); countdown(access) }
            }
        }.card(border: ShinobiStyle.accentBorder)
    }

    private func countdown(_ access: TemporaryAccess) -> some View {
        Text(timerInterval: Date.now...max(.now, access.deadline), countsDown: true)
            .monospacedDigit().shinobiFont(25, weight: .medium, relativeTo: .title2)
            .foregroundStyle(ShinobiStyle.accentBright).frame(width: countdownWidth, alignment: .trailing)
            .accessibilityLabel("一時解除の残り時間")
    }

}

struct RuleCard: View {
    let rule: LockRule
    let isAuthorized: Bool
    let working: Bool
    let edit: () -> Void
    let setEnabled: (Bool) -> Void

    var body: some View {
        // Sibling controls keep toggling independent from the card's edit action.
        Button(action: edit) {
            VStack(alignment: .leading, spacing: 10) {
                Text(rule.name).shinobiFont(15, weight: .medium)
                    .foregroundStyle(rule.isEnabled ? ShinobiStyle.text : ShinobiStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading).padding(.trailing, 60)
                Text(rule.timeText).monospacedDigit().shinobiFont(22, weight: .medium, relativeTo: .title3)
                    .foregroundStyle(rule.isEnabled ? ShinobiStyle.text : ShinobiStyle.muted)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { detail; Spacer(minLength: 0); badge }
                    VStack(alignment: .leading, spacing: 8) { detail; badge }
                }
            }
            .card(padding: 18)
        }
        .buttonStyle(.plain)
        .accessibilityHint("ルールを編集")
        .overlay(alignment: .topTrailing) {
            Toggle("\(rule.name)を有効にする", isOn: Binding(get: { rule.isEnabled }, set: setEnabled))
                .labelsHidden().tint(ShinobiStyle.accentFill)
                .frame(width: 52, height: 44).padding(.top, 11.5).padding(.trailing, 18)
                .disabled(working || (!isAuthorized && !rule.isEnabled))
        }
    }

    private var detail: some View {
        Text(rule.dayText + " · \(rule.applications.count)個のアプリ")
            .shinobiFont(13, relativeTo: .footnote)
            .foregroundStyle(rule.isEnabled ? ShinobiStyle.muted : ShinobiStyle.subdued)
    }

    @ViewBuilder private var badge: some View {
        if !rule.isEnabled {
            ShinobiBadge(title: "休止中", accented: false)
        } else if !isAuthorized {
            ShinobiBadge(title: "許可が必要", accented: false)
        } else if rule.schedule.contains(.now) {
            ShinobiBadge(title: "ロック時間中", symbol: "lock.fill")
        } else {
            ShinobiBadge(title: "有効", accented: false)
        }
    }
}

struct UnlockTarget: Identifiable {
    let id = UUID()
    let token: ApplicationToken
}
