import Foundation
import ManagedSettings
import DeviceActivity

final class TestStore {
    final class Shield { var applications: Set<ApplicationToken>? }
    let shield = Shield()
}
final class TestCenter {
    var activities: [DeviceActivityName] = []
    func startMonitoring(_ name: DeviceActivityName, during: DeviceActivitySchedule) throws {
        if !activities.contains(name) { activities.append(name) }
    }
    func stopMonitoring(_ names: [DeviceActivityName]) { activities.removeAll { names.contains($0) } }
}

@main
struct RuleActionChecks {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("shinobilock-rule-check-\(ProcessInfo.processInfo.processIdentifier)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let token = try JSONDecoder().decode(ApplicationToken.self, from: Data(#"{"data":"AQID"}"#.utf8))
        let otherToken = try JSONDecoder().decode(ApplicationToken.self, from: Data(#"{"data":"BAUG"}"#.utf8))
        let schedule = WeeklySchedule(weekdays: Set(1...7), startMinute: 0, endMinute: 1439)
        let first = LockRule(name: "検証ルール", schedule: schedule, applications: [token])
        let second = LockRule(name: "維持するルール", schedule: schedule, applications: [otherToken])
        try ProbeStorage.transaction(updateShield: true) { $0.rules = [first, second] }
        let before = try JSONEncoder().encode(ProbeStorage.snapshot()).count
        var checks = 0
        func require(_ condition: Bool, _ label: String) {
            precondition(condition, label)
            checks += 1
            print("PASS: " + label)
        }
        func snapshot() throws -> ProbeState { try ProbeStorage.snapshot() }

        let handoffTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!
        let request = UnlockRequest(token: token, requestedAt: handoffTime)
        try ProbeStorage.transaction { $0.pendingUnlockRequest = request }
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime) == token, "fresh Shield request opens its selected target")
        require(try snapshot().pendingUnlockRequest == nil, "request is consumed on disk before presentation")
        require(try snapshot().temporaryAccess == nil && ProbeControl.store.shield.applications == [token, otherToken],
                "opening confirmation does not unlock any app")
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime) == nil,
                "cancelled confirmation cannot replay on a later launch")

        let repeated = UnlockRequest(token: token, requestedAt: handoffTime)
        try ProbeStorage.transaction { $0.pendingUnlockRequest = repeated }
        require(try repeated.id != request.id && snapshot().pendingUnlockRequest?.id == repeated.id,
                "a new Shield tap for the same app has a new stored identity")
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime) == token, "a new explicit request still opens after cancellation")

        try ProbeStorage.transaction { $0.pendingUnlockRequest = request }
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime.addingTimeInterval(60)) == nil && snapshot().pendingUnlockRequest == nil,
                "unhandled request expires at 60 seconds and is removed")
        try ProbeStorage.transaction { $0.pendingUnlockRequest = request }
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime.addingTimeInterval(-1)) == nil,
                "future-dated request is discarded")
        let unknown = try JSONDecoder().decode(ApplicationToken.self, from: Data(#"{"data":"BwgJ"}"#.utf8))
        try ProbeStorage.transaction { $0.pendingUnlockRequest = UnlockRequest(token: unknown, requestedAt: handoffTime) }
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime) == nil, "unrestricted target cannot open an unlock flow")

        let existingAccess = TemporaryAccess(token: otherToken,
                                            window: AccessWindow(startedAt: handoffTime, startedUptime: ProcessInfo.processInfo.systemUptime),
                                            monitoringID: "existing-access")
        try ProbeStorage.transaction {
            $0.temporaryAccess = existingAccess
            $0.pendingUnlockRequest = request
        }
        require(try ProbeControl.consumeUnlockRequest(at: handoffTime) == nil && snapshot().temporaryAccess?.token == otherToken,
                "request during existing access is discarded without changing the grant")

        // Exercise the on-disk format written by build 8, including an active grant.
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot())) as! [String: Any]
        legacy["pendingApplication"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(token))
        try JSONSerialization.data(withJSONObject: legacy).write(to: directory.appendingPathComponent("state.json"), options: .atomic)
        let migrated = try snapshot()
        require(try migrated.pendingUnlockRequest == nil && ProbeControl.consumeUnlockRequest(at: handoffTime) == nil,
                "legacy pending target is ignored after an upgrade")
        require(migrated.rules == [first, second] && migrated.temporaryAccess?.deadline == existingAccess.deadline,
                "upgrade preserves rules and the existing access deadline")
        try ProbeStorage.transaction(updateShield: true) { $0.temporaryAccess = nil }

        var paused = first
        paused.isEnabled = false
        do {
            try ProbeControl.saveRule(paused)
            preconditionFailure("pause without reward succeeded")
        } catch ProbeError.pauseRequiresReward {}
        require(try snapshot().rules == [first, second], "direct pause rejected without changing stored rules")
        require(ProbeControl.store.shield.applications == [token, otherToken], "rejected pause keeps both shields")

        var gate = RewardGate()
        let cancelled = gate.begin()
        gate.finish()
        if gate.claim(cancelled) { try ProbeControl.saveRule(paused, authorizingPauseOf: first) }
        require(try snapshot().rules == [first, second], "cancelled or failed ad cannot pause")
        let earned = gate.begin()
        if gate.claim(earned) { try ProbeControl.saveRule(paused, authorizingPauseOf: first) }
        let afterPause = try snapshot()
        require(afterPause.rules[0].isEnabled == false && afterPause.rules[1] == second, "reward pauses only selected rule")
        require(ProbeControl.store.shield.applications == [otherToken], "unrelated app stays locked")
        require(!gate.claim(earned), "duplicate reward is ignored")

        let stale = afterPause.rules[0]
        var edited = stale
        edited.name = "更新済み"
        try ProbeControl.saveRule(edited)
        let current = try snapshot().rules[0]
        do {
            try ProbeControl.deleteRule(stale)
            preconditionFailure("stale delete succeeded")
        } catch ProbeError.ruleChanged {}
        require(try snapshot().rules[0] == current, "stale deletion preserves later edit")
        try ProbeControl.deleteRule(current)
        require(try snapshot().rules == [second], "rewarded deletion removes only selected rule")

        var weakening = second
        weakening.schedule.endMinute = 1438
        weakening.name = "通常編集"
        try ProbeControl.saveRule(weakening)
        require(try snapshot().rules[0].schedule.endMinute == 1438, "schedule edits still save without ads")
        let original = try snapshot().rules[0]
        var later = original
        later.name = "広告待ちの間の更新"
        try ProbeControl.saveRule(later)
        var stalePause = original
        stalePause.isEnabled = false
        do {
            try ProbeControl.saveRule(stalePause, authorizingPauseOf: original)
            preconditionFailure("stale pause succeeded")
        } catch ProbeError.ruleChanged {}
        require(try snapshot().rules[0].isEnabled && snapshot().rules[0].name == later.name, "stale pause preserves later edit")

        try ProbeControl.unlockForFiveMinutes(otherToken)
        let access = try snapshot().temporaryAccess!
        require(access.isValid() && access.token == otherToken, "five-minute reward still grants selected app access")
        require(abs(access.deadline.timeIntervalSince(access.window.startedAt) - 300) < 0.01, "five-minute deadline remains unchanged")
        require(ProbeControl.store.shield.applications == nil, "temporary grant removes selected shield")
        require(before > 0, "state serialization works")
        print("\(checks) rule-action and unlock-intent checks passed. DeviceActivity and ManagedSettings are test doubles; persistence and control code are real.")
    }
}
