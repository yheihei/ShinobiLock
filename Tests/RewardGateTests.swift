import XCTest
@testable import ShinobiLockCore

final class RewardGateTests: XCTestCase {
    func testDuplicateRewardCannotExtendAccess() {
        var gate = RewardGate()
        let ad = gate.begin()
        XCTAssertTrue(gate.claim(ad))
        XCTAssertFalse(gate.claim(ad))
    }

    func testDismissalAndFailureInvalidateLateRewards() {
        var gate = RewardGate()
        let ad = gate.begin()
        gate.finish()
        XCTAssertFalse(gate.claim(ad))
    }

    func testOldAdCannotUnlockDuringAnotherAttempt() {
        var gate = RewardGate()
        let old = gate.begin()
        let current = gate.begin()
        XCTAssertFalse(gate.claim(old))
        XCTAssertTrue(gate.claim(current))
    }
}
