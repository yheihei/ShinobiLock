import XCTest
@testable import ShinobiLockCore

final class RewardGateTests: XCTestCase {
    func testDuplicateRewardCannotExtendAccess() {
        var gate = RewardGate()
        let ad = gate.begin()
        XCTAssertFalse(gate.claim(ad))
        XCTAssertTrue(gate.present(ad))
        XCTAssertTrue(gate.claim(ad))
        XCTAssertFalse(gate.claim(ad))
        XCTAssertFalse(gate.offerFallback(ad, at: 100))
    }

    func testDismissalAndFailureInvalidateLateRewards() {
        var gate = RewardGate()
        let ad = gate.begin()
        XCTAssertTrue(gate.present(ad))
        gate.finish()
        XCTAssertFalse(gate.claim(ad))
        XCTAssertFalse(gate.offerFallback(ad, at: 100))
        XCTAssertFalse(gate.claimFallback(at: 1000))
    }

    func testOldAdCannotUnlockDuringAnotherAttempt() {
        var gate = RewardGate()
        let old = gate.begin()
        let current = gate.begin()
        XCTAssertFalse(gate.present(old))
        XCTAssertFalse(gate.offerFallback(old, at: 100))
        XCTAssertTrue(gate.present(current))
        XCTAssertFalse(gate.claim(old))
        XCTAssertTrue(gate.claim(current))
    }

    func testTimeoutRejectsLateAdAndRequiresFullWaitAndConfirmation() {
        var gate = RewardGate()
        let ad = gate.begin()
        XCTAssertTrue(gate.offerFallback(ad, at: 100))
        XCTAssertFalse(gate.present(ad))
        XCTAssertFalse(gate.claim(ad))
        XCTAssertFalse(gate.offerFallback(ad, at: 102))
        XCTAssertEqual(gate.secondsRemaining(at: 109.9), 1)
        XCTAssertFalse(gate.claimFallback(at: 109.9))
        XCTAssertEqual(gate.secondsRemaining(at: 110), 0)
        XCTAssertEqual(gate.phase, .waiting) // Time passing never grants by itself.
        XCTAssertTrue(gate.claimFallback(at: 110))
        XCTAssertFalse(gate.claimFallback(at: 111))
        XCTAssertFalse(gate.claim(ad))
    }

    func testPresentationFailureCanWaitButEarlyDismissalCannot() {
        var gate = RewardGate()
        let failed = gate.begin()
        XCTAssertTrue(gate.present(failed))
        XCTAssertTrue(gate.offerFallback(failed, at: 10))
        XCTAssertTrue(gate.claimFallback(at: 20))
        let dismissed = gate.begin()
        XCTAssertTrue(gate.present(dismissed))
        gate.finish()
        XCTAssertFalse(gate.offerFallback(dismissed, at: 30))
    }

    func testCancelOrBackgroundInvalidatesWaitAndReopeningStartsOver() {
        var gate = RewardGate()
        let first = gate.begin()
        XCTAssertTrue(gate.offerFallback(first, at: 100))
        gate.finish()
        XCTAssertFalse(gate.claimFallback(at: 120))
        let next = gate.begin()
        XCTAssertTrue(gate.offerFallback(next, at: 120))
        XCTAssertFalse(gate.claimFallback(at: 129.99))
        XCTAssertTrue(gate.claimFallback(at: 130))
    }

    func testMonotonicTimeGoingBackwardCannotCompleteWait() {
        var gate = RewardGate()
        let ad = gate.begin()
        XCTAssertTrue(gate.offerFallback(ad, at: 100))
        XCTAssertEqual(gate.secondsRemaining(at: 90), 10)
        XCTAssertFalse(gate.claimFallback(at: 90))
    }
}
