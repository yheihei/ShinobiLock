import SwiftUI
import FamilyControls
import ManagedSettings

enum ShinobiStyle {
    static let ink = Color(red: 0.13, green: 0.23, blue: 0.20)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.90)
    static let muted = Color(red: 0.32, green: 0.38, blue: 0.34)
    static let accent = Color(red: 0.78, green: 0.88, blue: 0.56)
}

@main
struct ShinobiLockApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(ShinobiStyle.ink)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }
}

struct HomeView: View {
    @StateObject private var model = LockModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingRule: LockRule?
    @State private var showingSettings = false
    @State private var unlockTarget: UnlockTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if !model.isAuthorized { permissionCard }
                    if let access = model.state.temporaryAccess, access.isValid() {
                        accessCard(access)
                    }
                    if let token = model.state.pendingApplication, model.lockedApplications.contains(token) {
                        pendingCard(token)
                    }
                    HStack {
                        Text("時間帯ルール").font(.title2.bold())
                        Spacer()
                        Text("\(model.state.rules.count)件").foregroundStyle(ShinobiStyle.muted)
                    }
                    if model.state.rules.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "calendar.badge.clock").font(.largeTitle)
                            Text("集中したい時間を決めよう").font(.headline)
                            Text("曜日・時間帯・アプリを選ぶと、その時間だけ自動でロックします。")
                                .foregroundStyle(ShinobiStyle.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                    ForEach(model.state.rules) { rule in ruleCard(rule) }
                    Button { editingRule = .newDraft } label: {
                        Label("ルールをつくる", systemImage: "plus")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(!model.isAuthorized || model.working)
                    Text("必要なときは、ロック画面から広告を見て、そのアプリだけ5分間使えます。")
                        .font(.footnote).foregroundStyle(ShinobiStyle.muted)
                }.padding(20)
            }
            .background(ShinobiStyle.paper)
            .foregroundStyle(ShinobiStyle.ink)
            .navigationTitle("忍びロック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("設定", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(item: $editingRule) { RuleEditorView(model: model, rule: $0) }
            .sheet(item: $unlockTarget) { UnlockView(model: model, token: $0.token) }
            .sheet(isPresented: $showingSettings) { SettingsView(model: model) }
            .alert("確認してください", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
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
            .onChange(of: model.state.pendingApplication) { _, token in
                if token != nil { presentPendingTarget() }
            }
        }
    }

    private func presentPendingTarget() {
        guard editingRule == nil, !showingSettings, unlockTarget == nil,
              let token = model.state.pendingApplication, model.lockedApplications.contains(token) else { return }
        unlockTarget = UnlockTarget(token: token)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(model.lockedApplications.isEmpty ? "自分のペースで" : "ただいま集中中", systemImage: model.lockedApplications.isEmpty ? "leaf" : "lock.fill")
                .font(.subheadline.bold()).foregroundStyle(ShinobiStyle.accent)
            Text("大切な時間を、\n自分の手に。").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(statusText).font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        .foregroundStyle(.white).background(ShinobiStyle.ink, in: RoundedRectangle(cornerRadius: 28))
    }

    private var statusText: String {
        if !model.isAuthorized { return "まずはスクリーンタイムを許可して、準備をはじめましょう。" }
        if !model.lockedApplications.isEmpty { return "\(model.lockedApplications.count)個のアプリをロックしています。" }
        if let next = model.state.rules.filter(\.isEnabled).compactMap({ $0.schedule.nextBoundary(after: .now) }).min() {
            return "次の切り替えは " + next.formatted(.dateTime.weekday().hour().minute())
        }
        return "ルールを設定して、集中する時間をつくりましょう。"
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("スクリーンタイムの許可", systemImage: "hand.raised").font(.headline)
            Text("選んだアプリを決めた時間だけロックするために使います。許可はiPhoneの設定からいつでも取り消せます。")
                .font(.subheadline)
            Button("スクリーンタイムを許可する") { Task { await model.authorize() } }
                .buttonStyle(.borderedProminent)
        }.card()
    }

    private func ruleCard(_ rule: LockRule) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { rule.isEnabled }, set: { value in
                var updated = rule
                updated.isEnabled = value
                model.handle { try model.save(updated) }
            })) {
                Text(rule.name).font(.headline)
            }.disabled(model.working || (!model.isAuthorized && !rule.isEnabled))
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(rule.timeText).font(.title2.monospacedDigit().bold())
                    Text(rule.dayText + "  ·  \(rule.applications.count)個のアプリ")
                        .font(.subheadline).foregroundStyle(ShinobiStyle.muted)
                }
                Spacer()
                Button("編集") { editingRule = rule }.buttonStyle(.bordered)
            }
            if rule.isEnabled && rule.schedule.contains(.now) && model.isAuthorized {
                Label("ロック時間中", systemImage: "lock.fill").font(.caption.bold())
            }
        }.card()
    }

    private func accessCard(_ access: TemporaryAccess) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(access.token).font(.headline)
            HStack {
                Text("一時解除中")
                Spacer()
                Text(timerInterval: Date.now...max(.now, access.deadline), countsDown: true)
                    .monospacedDigit().font(.title2.bold()).frame(width: 90, alignment: .trailing)
            }
            Text("残り時間が終わると、ルールに合わせて再ロックします。")
                .font(.footnote).foregroundStyle(ShinobiStyle.muted)
        }.card()
    }

    private func pendingCard(_ token: ApplicationToken) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(token).font(.headline)
            Text("少しだけ使いますか？")
            Button("5分だけ使う") { unlockTarget = UnlockTarget(token: token) }
                .buttonStyle(.borderedProminent)
        }.card()
    }
}

struct UnlockTarget: Identifiable {
    let id = UUID()
    let token: ApplicationToken
}

extension View {
    func card() -> some View {
        padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
