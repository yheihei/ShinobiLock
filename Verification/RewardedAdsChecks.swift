import SwiftUI

@main @MainActor struct RewardedAdsChecks {
    static func main() async {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
        }
        let ads = RewardedAds()
        var grants = 0
        // Privacy/network failure, followed by explicit confirmation at the boundary.
        TestAds.privacyFails = true
        await ads.show(eligible: { true }, reward: { grants += 1 })
        check(ads.fallbackEncounter != nil && ads.busy, "Consent service failure offers fallback")
        ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        check(grants == 0, "No early grant")
        TestClock.uptime = 110
        ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        check(grants == 1 && ads.granted && !ads.busy, "Only one explicit grant")
        TestAds.privacyFails = false
        // Same flow serves unlock, pause and delete callbacks; a changed rule is rejected.
        for _ in 0..<3 {
            await ads.show(eligible: { true }, reward: { grants += 1 })
            TestClock.uptime += 10
            ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        }
        check(grants == 4, "Action callbacks complete once")
        await ads.show(eligible: { true }, reward: { grants += 1 })
        TestClock.uptime += 10
        ads.confirmFallback(eligible: { false }, perform: { grants += 1 })
        check(grants == 4 && !ads.granted && !ads.busy, "Changed target rejected")
        // Leaving the app or cancelling invalidates the waiting state.
        await ads.show(eligible: { true }, reward: { grants += 1 })
        ads.cancel()
        TestClock.uptime += 10
        ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        check(grants == 4 && ads.fallbackEncounter == nil, "Cancel invalidates confirmation")
        await ads.show(eligible: { true }, reward: { grants += 1 })
        TestClock.uptime += 10
        TestApplication.state = .background
        ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        check(grants == 4 && !ads.busy, "No background confirmation")
        TestApplication.state = .active
        // Early dismissal does not offer a shortcut; late reward callbacks are ignored.
        TestAds.mode = .success
        await ads.show(eligible: { true }, reward: { grants += 1 })
        let early = TestAds.latest!
        early.fullScreenContentDelegate?.adDidDismissFullScreenContent(early)
        early.reward?()
        check(grants == 4 && ads.fallbackEncounter == nil && !ads.granted, "Early close keeps lock")
        await ads.show(eligible: { true }, reward: { grants += 1 })
        let success = TestAds.latest!
        success.reward?(); success.reward?()
        success.fullScreenContentDelegate?.adDidDismissFullScreenContent(success)
        check(grants == 5 && ads.granted && !ads.busy, "Normal ad reward still works once")
        // Presentation errors offer fallback, but cannot grant through a stale reward.
        await ads.show(eligible: { true }, reward: { grants += 1 })
        let failed = TestAds.latest!
        failed.fullScreenContentDelegate?.ad(failed, didFailToPresentFullScreenContentWithError: AdError.unavailable)
        failed.reward?()
        check(ads.fallbackEncounter != nil && grants == 5, "Presentation failure uses waiting path")
        ads.cancel()
        // SDK ignores cancellation: timeout must finish independently and reject late load.
        TestAds.mode = .suspended
        let pending = Task { await ads.show(eligible: { true }, reward: { grants += 1 }) }
        try? await Task.sleep(for: .milliseconds(150))
        check(ads.fallbackEncounter != nil, "Timeout does not wait for SDK return")
        let presentations = TestAds.presentations
        TestClock.uptime += 10
        ads.confirmFallback(eligible: { true }, perform: { grants += 1 })
        TestAds.continuation?.resume(returning: RewardedAd())
        await pending.value
        check(grants == 6 && TestAds.presentations == presentations, "Late ad cannot display or regrant")
        // An older cancelled load must not overwrite the next attempt's fallback.
        let old = Task { await ads.show(eligible: { true }, reward: { grants += 1 }) }
        try? await Task.sleep(for: .milliseconds(5))
        ads.cancel(); old.cancel()
        TestAds.mode = .failure
        await ads.show(eligible: { true }, reward: { grants += 1 })
        let encounterID = ads.fallbackEncounter?.id
        TestAds.continuation?.resume(throwing: AdError.unavailable)
        await old.value
        check(ads.fallbackEncounter?.id == encounterID && ads.busy, "Stale failure leaves new attempt alone")
        ads.cancel()
        print("RewardedAds controller: \(count) checks passed")
    }
}
