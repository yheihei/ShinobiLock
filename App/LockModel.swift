import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

@MainActor
final class LockModel: ObservableObject {
    @Published private(set) var state = ProbeState()
    @Published private(set) var authorization = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var working = false
    @Published var errorMessage: String?
    private var lastEvidence: Data?

    var isAuthorized: Bool { authorization == .approved }
    var lockedApplications: Set<ApplicationToken> {
        guard isAuthorized else { return [] }
        var result = state.lockedApplications
        if let access = state.temporaryAccess, access.isValid() { result.remove(access.token) }
        return result
    }

    func refresh() {
        authorization = AuthorizationCenter.shared.authorizationStatus
        do {
            state = try ProbeStorage.snapshot()
            #if DEBUG
            let data = try JSONEncoder().encode(state)
            if data != lastEvidence {
                let url = URL.documentsDirectory.appendingPathComponent("probe-evidence.json")
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                lastEvidence = data
            }
            #endif
        } catch { errorMessage = error.localizedDescription }
    }

    func synchronize() {
        refresh()
        guard isAuthorized else { return }
        handle { try mutate { try ProbeControl.restoreMonitoring() } }
    }

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            synchronize()
        } catch {
            refresh()
            errorMessage = "スクリーンタイムを許可できませんでした。設定アプリの「スクリーンタイム」から、忍びロックのアクセスを確認してください。"
        }
    }

    func save(_ rule: LockRule) throws {
        if rule.isEnabled && !isAuthorized { throw AppError.permissionRequired }
        try mutate { try ProbeControl.saveRule(rule) }
    }

    func delete(_ id: UUID) throws { try mutate { try ProbeControl.deleteRule(id) } }
    func pauseAll() throws { try mutate { try ProbeControl.clear() } }

    func unlock(_ token: ApplicationToken) throws {
        authorization = AuthorizationCenter.shared.authorizationStatus
        guard isAuthorized else { throw AppError.permissionRequired }
        try mutate { try ProbeControl.unlockForFiveMinutes(token) }
    }

    func handle(_ operation: () throws -> Void) {
        do { try operation() }
        catch { errorMessage = error.localizedDescription }
    }

    private func mutate(_ operation: () throws -> Void) throws {
        guard !working else { throw AppError.busy }
        working = true
        let assertion = UIApplication.shared.beginBackgroundTask(withName: "Save lock settings")
        defer {
            if assertion != .invalid { UIApplication.shared.endBackgroundTask(assertion) }
            working = false
            refresh()
        }
        try operation()
    }
}

enum AppError: LocalizedError {
    case permissionRequired, busy
    var errorDescription: String? {
        switch self {
        case .permissionRequired: return "ルールを有効にするには、スクリーンタイムの利用を許可してください。"
        case .busy: return "設定を保存しています。少し待ってからお試しください。"
        }
    }
}

extension LockRule {
    static var newDraft: LockRule {
        LockRule(name: "", schedule: WeeklySchedule(weekdays: Set(2...6), startMinute: 540, endMinute: 1080), applications: [])
    }

    var dayText: String {
        if schedule.weekdays == Set(1...7) { return "毎日" }
        if schedule.weekdays == Set(2...6) { return "平日" }
        return [2, 3, 4, 5, 6, 7, 1].filter { schedule.weekdays.contains($0) }.map { Self.dayName($0) }.joined(separator: "・")
    }

    static func dayName(_ day: Int) -> String { ["", "日", "月", "火", "水", "木", "金", "土"][day] }
    static func timeText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    var timeText: String { Self.timeText(schedule.startMinute) + " – " + Self.timeText(schedule.endMinute) }
}
