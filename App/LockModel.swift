import SwiftUI
import FamilyControls
import ManagedSettings
import UIKit

@MainActor
final class LockModel: ObservableObject {
    @Published private(set) var state = ProbeState()
    @Published private(set) var authorization = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var working = false
    @Published private(set) var authorizing = false
    @Published private(set) var authorizationMessage: String?
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
        guard !authorizing else { return }
        authorizing = true
        authorizationMessage = nil
        defer { authorizing = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            synchronize()
        } catch {
            refresh()
            authorizationMessage = "iPhoneの設定 › スクリーンタイムで、カルマロックのアクセスを確認してください。"
        }
    }

    func save(_ rule: LockRule) throws {
        if rule.isEnabled && !isAuthorized { throw AppError.permissionRequired }
        try mutate { try ProbeControl.saveRule(rule) }
    }

    func canPerform(_ request: RuleActionRequest) -> Bool {
        state.rules.first(where: { $0.id == request.original.id }) == request.original
    }

    // Called only by the reward callback. Storage checks the original revision again
    // inside its transaction so a stale ad cannot overwrite a subsequent edit.
    func performRewardedAction(_ request: RuleActionRequest) throws {
        try mutate {
            if let updated = request.updated {
                try ProbeControl.saveRule(updated, authorizingPauseOf: request.original)
            } else {
                try ProbeControl.deleteRule(request.original)
            }
        }
    }

    func unlock(_ token: ApplicationToken) throws {
        authorization = AuthorizationCenter.shared.authorizationStatus
        guard isAuthorized else { throw AppError.permissionRequired }
        try mutate { try ProbeControl.unlockForFiveMinutes(token) }
    }

    func consumeUnlockRequest() throws -> ApplicationToken? {
        guard isAuthorized else { return nil }
        var token: ApplicationToken?
        try mutate { token = try ProbeControl.consumeUnlockRequest() }
        return token
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
        if schedule.weekdays == Set(2...6) { return "月〜金" }
        if schedule.weekdays == Set([1, 7]) { return "土・日" }
        return [2, 3, 4, 5, 6, 7, 1].filter { schedule.weekdays.contains($0) }.map { Self.dayName($0) }.joined(separator: "・")
    }

    static func dayName(_ day: Int) -> String { ["", "日", "月", "火", "水", "木", "金", "土"][day] }
    static func timeText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    var timeText: String { Self.timeText(schedule.startMinute) + " – " + Self.timeText(schedule.endMinute) }
}
