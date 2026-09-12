import Foundation
import Testing
@testable import ShinobiLockCore

private let beginning = Date(timeIntervalSince1970: 1_800_000_000)
private let window = AccessWindow(startedAt: beginning, startedUptime: 1_000)

@Test func accessEndsAtFiveMinutes() {
    #expect(window.isValid(now: beginning, uptime: 1_000))
    #expect(window.isValid(now: beginning.addingTimeInterval(299.9), uptime: 1_299.9))
    #expect(!window.isValid(now: beginning.addingTimeInterval(300), uptime: 1_300))
}

@Test func movingWallClockBackwardDoesNotExtendAccess() {
    #expect(!window.isValid(now: beginning.addingTimeInterval(120), uptime: 1_300))
    #expect(!window.isValid(now: beginning.addingTimeInterval(-1), uptime: 1_001))
}

@Test func clockDiscontinuityEndsAccessEarly() {
    #expect(!window.isValid(now: beginning.addingTimeInterval(200), uptime: 1_020))
    #expect(!window.isValid(now: beginning.addingTimeInterval(20), uptime: 1_200))
}

@Test func resetUptimeInvalidatesAccess() {
    #expect(!window.isValid(now: beginning.addingTimeInterval(60), uptime: 10))
}

@Test func persistenceDoesNotRestartTheFiveMinuteWindow() throws {
    let encoded = try JSONEncoder().encode(window)
    let restored = try JSONDecoder().decode(AccessWindow.self, from: encoded)
    #expect(restored.deadline == beginning.addingTimeInterval(300))
    #expect(restored.isValid(now: beginning.addingTimeInterval(240), uptime: 1_240))
    #expect(!restored.isValid(now: beginning.addingTimeInterval(301), uptime: 1_301))
}
