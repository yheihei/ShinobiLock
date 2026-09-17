import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Darwin
import os

enum ProbeError: LocalizedError {
    case appGroupMissing
    case noApplication
    case alreadyUnlocked
    case invalidName
    case tooManyApplications
    case tooManyOverlappingApplications
    case ruleChanged
    case pauseRequiresReward

    var errorDescription: String? {
        switch self {
        case .appGroupMissing: return "共有領域を開けません。App Groupsと署名設定を確認してください。"
        case .noApplication: return "対象アプリを確認してください。設定には1つ以上のアプリが必要で、一時解除はロック時間中だけ利用できます。"
        case .alreadyUnlocked: return "ほかのアプリを一時解除中のため、解除できません。"
        case .invalidName: return "ルール名は1〜30文字で入力してください。"
        case .tooManyApplications: return "1つのルールで選べるアプリは\(LockRule.maximumApplications)個までです。対象アプリを減らしてください。"
        case .tooManyOverlappingApplications: return "ほかのルールと合わせて、同じ時間にロックするアプリが\(LockRule.maximumApplications)個を超えます。対象アプリを減らすか、曜日・時間をずらしてください。"
        case .ruleChanged: return "ルールが変更されています。画面を閉じて、内容を確認してください。"
        case .pauseRequiresReward: return "ルールを休止するには、休止の確認画面から操作してください。"
        }
    }
}

struct LockRule: Codable, Identifiable, Equatable {
    static let maximumApplications = 50

    var id: UUID = UUID()
    var name: String
    var schedule: WeeklySchedule
    var applications: Set<ApplicationToken>
    var isEnabled: Bool = true
    var monitoringID: String = "shinobilock.rule." + UUID().uuidString
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var scheduledApplications: ScheduledApplications<ApplicationToken> {
        ScheduledApplications(schedule: schedule, applications: applications, enabled: isEnabled)
    }

    func validate() throws {
        guard (1...30).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count) else { throw ProbeError.invalidName }
        try schedule.validate()
        guard !applications.isEmpty else { throw ProbeError.noApplication }
        guard applications.count <= Self.maximumApplications else { throw ProbeError.tooManyApplications }
    }
}

struct TemporaryAccess: Codable {
    let token: ApplicationToken
    let window: AccessWindow
    let monitoringID: String

    var deadline: Date { window.deadline }

    func isValid(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        window.isValid(now: now, uptime: uptime)
    }
}

struct ProbeEvent: Codable, Identifiable {
    var id = UUID()
    var timestamp = Date()
    var kind: String
    var application: ApplicationToken?
    var note: String?
}

struct UnlockRequest: Codable, Identifiable, Equatable {
    var id = UUID()
    let token: ApplicationToken
    var requestedAt = Date()

    // This is only the Shield-to-app handoff, not the five-minute access window.
    // An unhandled request must not become an invitation on a later app launch.
    func isRecent(at date: Date) -> Bool {
        let age = date.timeIntervalSince(requestedAt)
        return age >= 0 && age < 60
    }
}

struct ProbeState: Codable {
    var rules: [LockRule] = []
    var lockedApplications: Set<ApplicationToken> = []
    var pendingUnlockRequest: UnlockRequest?
    var temporaryAccess: TemporaryAccess?
    var events: [ProbeEvent] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case rules, lockedApplications, pendingUnlockRequest, temporaryAccess, events
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // The first physical prototype predates weekly rules.
        rules = try values.decodeIfPresent([LockRule].self, forKey: .rules) ?? []
        lockedApplications = try values.decodeIfPresent(Set<ApplicationToken>.self, forKey: .lockedApplications) ?? []
        // Ignore the old pendingApplication key: it may be an already-cancelled request.
        pendingUnlockRequest = try values.decodeIfPresent(UnlockRequest.self, forKey: .pendingUnlockRequest)
        temporaryAccess = try values.decodeIfPresent(TemporaryAccess.self, forKey: .temporaryAccess)
        events = try values.decodeIfPresent([ProbeEvent].self, forKey: .events) ?? []
    }

    func applicationsRestrictedByRules(at date: Date = .now) -> Set<ApplicationToken> {
        RuleEvaluator.lockedApplications(from: rules.map(\.scheduledApplications), at: date)
    }

    mutating func record(_ kind: String, application: ApplicationToken? = nil, note: String? = nil) {
        events.append(ProbeEvent(kind: kind, application: application, note: note))
        if events.count > 300 { events.removeFirst(events.count - 300) }
    }
}

enum ProbeStorage {
    private static let logger = Logger(subsystem: "ShinobiLock", category: "ProbeStorage")

    private static func directory() throws -> URL {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ShinobiAppGroup") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw ProbeError.appGroupMissing }
        let directory = container.appendingPathComponent("Probe", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // Reads never acquire the writer lock. Atomic replacement gives readers either
    // complete version, and iOS can suspend a reader without a 0xdead10cc termination.
    static func snapshot() throws -> ProbeState {
        try readState(in: directory())
    }

    private static func readState(in directory: URL) throws -> ProbeState {
        let url = directory.appendingPathComponent("state.json")
        do { return try JSONDecoder().decode(ProbeState.self, from: Data(contentsOf: url)) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return ProbeState()
        }
    }

    // Writers serialize state and shield changes. The main app must obtain a UIKit
    // background assertion before entering; extensions call from OS request handlers.
    // Never wait for another process while handling a Shield configuration request.
    static func transaction<T>(updateShield: Bool = false,
                               _ body: (inout ProbeState) throws -> T) throws -> T {
        let directory = try directory()
        let lockPath = directory.appendingPathComponent("state.lock").path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(descriptor) }
        let lockDeadline = ProcessInfo.processInfo.systemUptime + 1
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            let code = errno
            guard (code == EWOULDBLOCK || code == EAGAIN),
                  ProcessInfo.processInfo.systemUptime < lockDeadline else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
            }
            usleep(10_000)
        }
        defer { flock(descriptor, LOCK_UN) }

        let url = directory.appendingPathComponent("state.json")
        var state = try readState(in: directory)
        let result = try body(&state)
        if updateShield { ProbeControl.expireGrant(&state) }
        try JSONEncoder().encode(state).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        // Persist the deadline before unshielding. Failed writes must not grant access.
        if updateShield { ProbeControl.apply(state) }
        return result
    }

    static func attempt(_ operation: () throws -> Void) {
        do { try operation() }
        catch { logger.error("Probe operation failed: \(error.localizedDescription, privacy: .public)") }
    }
}

enum ProbeControl {
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("ShinobiLock.Probe"))
    static let center = DeviceActivityCenter()
    static let activityPrefix = "shinobilock.pause."
    static let rulePrefix = "shinobilock.rule."

    static func expireGrant(_ state: inout ProbeState) {
        state.lockedApplications = state.applicationsRestrictedByRules()
        if let access = state.temporaryAccess,
           !access.isValid() || !state.lockedApplications.contains(access.token) {
            state.temporaryAccess = nil
            state.record("一時解除を終了", application: access.token)
        }
        if let request = state.pendingUnlockRequest,
           !request.isRecent(at: .now) || !state.lockedApplications.contains(request.token) {
            state.pendingUnlockRequest = nil
        }
    }

    // Persist consumption before presenting any UI. Cancellation, app termination,
    // and subsequent foreground refreshes can never replay the same request.
    static func consumeUnlockRequest(at date: Date = .now) throws -> ApplicationToken? {
        try ProbeStorage.transaction { state in
            let request = state.pendingUnlockRequest
            state.pendingUnlockRequest = nil
            guard let request, request.isRecent(at: date),
                  state.applicationsRestrictedByRules(at: date).contains(request.token),
                  state.temporaryAccess?.isValid(now: date) != true else { return nil }
            return request.token
        }
    }

    // Call only after persisting state, while holding the shared transaction lock.
    static func apply(_ state: ProbeState) {
        var applications = state.lockedApplications
        if let access = state.temporaryAccess, access.isValid() { applications.remove(access.token) }
        store.shield.applications = applications.isEmpty ? nil : applications
    }

    static func reconcile(reason: String) throws {
        try ProbeStorage.transaction(updateShield: true) { state in
            if state.lockedApplications != state.applicationsRestrictedByRules()
                || state.temporaryAccess.map({ !$0.isValid() }) == true {
                state.record(reason)
            }
        }
    }

    static func deviceSchedule(for rule: LockRule) -> DeviceActivitySchedule {
        let schedule = rule.schedule
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.startMinute / 60, minute: schedule.startMinute % 60),
            intervalEnd: DateComponents(hour: schedule.monitoringEndMinute / 60, minute: schedule.monitoringEndMinute % 60),
            repeats: true,
            warningTime: schedule.endWarningMinutes.map { DateComponents(minute: $0) }
        )
    }

    static func saveRule(_ proposed: LockRule, authorizingPauseOf expected: LockRule? = nil) throws {
        var rule = proposed
        rule.name = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.updatedAt = .now
        rule.monitoringID = rulePrefix + UUID().uuidString
        try rule.validate()
        let previous = try ProbeStorage.snapshot().rules.first { $0.id == rule.id }
        let activity = DeviceActivityName(rule.monitoringID)
        // Register first. A failed registration must not replace a working rule.
        // A callback that arrives before commit has no matching revision and is ignored.
        if rule.isEnabled { try center.startMonitoring(activity, during: deviceSchedule(for: rule)) }
        do {
            try ProbeStorage.transaction(updateShield: true) { state in
                let current = state.rules.first { $0.id == rule.id }
                if let expected {
                    guard current == expected, expected.isEnabled, !rule.isEnabled else { throw ProbeError.ruleChanged }
                } else if current?.isEnabled == true && !rule.isEnabled {
                    // Ordinary edits remain ad-free; pausing requires the confirmed action flow.
                    throw ProbeError.pauseRequiresReward
                }
                if let index = state.rules.firstIndex(where: { $0.id == rule.id }) {
                    state.rules[index] = rule
                } else {
                    state.rules.append(rule)
                }
                guard !RuleEvaluator.exceedsApplicationLimit(from: state.rules.map(\.scheduledApplications),
                                                             maximum: LockRule.maximumApplications)
                else { throw ProbeError.tooManyOverlappingApplications }
                state.record("ルールを保存", note: rule.id.uuidString)
            }
        } catch {
            if rule.isEnabled { center.stopMonitoring([activity]) }
            throw error
        }
        if let previous { center.stopMonitoring([DeviceActivityName(previous.monitoringID)]) }
        stopExpiredPauseMonitoring()
    }

    static func deleteRule(_ expected: LockRule) throws {
        let previous = try ProbeStorage.transaction(updateShield: true) { state in
            guard let previous = state.rules.first(where: { $0.id == expected.id }), previous == expected else {
                throw ProbeError.ruleChanged
            }
            state.rules.removeAll { $0.id == expected.id }
            state.record("ルールを削除", note: expected.id.uuidString)
            return previous
        }
        center.stopMonitoring([DeviceActivityName(previous.monitoringID)])
        stopExpiredPauseMonitoring()
    }

    static func restoreMonitoring() throws {
        let state = try ProbeStorage.snapshot()
        let existing = Set(center.activities.map(\.rawValue))
        let enabled = state.rules.filter(\.isEnabled)
        for rule in enabled where !existing.contains(rule.monitoringID) {
            try rule.validate()
            try center.startMonitoring(DeviceActivityName(rule.monitoringID), during: deviceSchedule(for: rule))
        }
        let currentIDs = Set(enabled.map(\.monitoringID)).union([state.temporaryAccess?.monitoringID].compactMap { $0 })
        let obsolete = center.activities.filter {
            ($0.rawValue.hasPrefix(rulePrefix) || $0.rawValue.hasPrefix(activityPrefix)) && !currentIDs.contains($0.rawValue)
        }
        if !obsolete.isEmpty { center.stopMonitoring(obsolete) }
        try reconcile(reason: "アプリ起動時にロックを調整")
    }

    static func stopExpiredPauseMonitoring() {
        guard let state = try? ProbeStorage.snapshot() else { return }
        let obsolete = center.activities.filter {
            $0.rawValue.hasPrefix(activityPrefix) && $0.rawValue != state.temporaryAccess?.monitoringID
        }
        if !obsolete.isEmpty { center.stopMonitoring(obsolete) }
    }

    static func unlockForFiveMinutes(_ token: ApplicationToken) throws {
        let now = Date()
        let activity = DeviceActivityName(activityPrefix + UUID().uuidString)
        let access = TemporaryAccess(token: token,
                                     window: AccessWindow(startedAt: now, startedUptime: ProcessInfo.processInfo.systemUptime),
                                     monitoringID: activity.rawValue)

        // DeviceActivity requires intervals of at least 15 minutes. We use
        // a 16-minute interval with an 11-minute warning to request a callback at +5m.
        // The actual callback delivery time must be measured on a physical device.
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let start = Calendar.current.dateComponents(components, from: now)
        let end = Calendar.current.dateComponents(components, from: now.addingTimeInterval(16 * 60))
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end,
                                              repeats: false, warningTime: DateComponents(minute: 11))
        let state = try ProbeStorage.snapshot()
        guard state.applicationsRestrictedByRules().contains(token) else { throw ProbeError.noApplication }
        guard state.temporaryAccess?.isValid() != true else { throw ProbeError.alreadyUnlocked }
        // A registration error leaves the app locked. Do not claim that a foreground
        // Timer can enforce a deadline while the containing app is terminated.
        try center.startMonitoring(activity, during: schedule)
        do {
            try ProbeStorage.transaction(updateShield: true) { state in
                guard state.applicationsRestrictedByRules().contains(token) else { throw ProbeError.noApplication }
                guard state.temporaryAccess?.isValid() != true else { throw ProbeError.alreadyUnlocked }
                state.temporaryAccess = access
                state.pendingUnlockRequest = nil
                state.record("5分解除を開始", application: token, note: activity.rawValue)
            }
        } catch {
            center.stopMonitoring([activity])
            throw error
        }
    }

    static func monitorCallback(_ name: DeviceActivityName, kind: String, forceEnd: Bool) throws {
        if name.rawValue.hasPrefix(rulePrefix) {
            try ProbeStorage.transaction(updateShield: true) { state in
                guard state.rules.contains(where: { $0.isEnabled && $0.monitoringID == name.rawValue }) else { return }
                state.record("時間帯ルールの通知: " + kind, note: name.rawValue)
            }
            return
        }
        guard name.rawValue.hasPrefix(activityPrefix) else { return }
        try ProbeStorage.transaction(updateShield: true) { state in
            state.record(kind, note: name.rawValue)
            if forceEnd, state.temporaryAccess?.monitoringID == name.rawValue {
                // A warning is an explicit relock signal, including if iOS delivers
                // it fractionally before the stored deadline because of rounding.
                state.temporaryAccess = nil
            }
        }
    }
}
