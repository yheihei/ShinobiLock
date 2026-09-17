// Only compiled by scripts/check_rewarded_ads.py, never by the app target.
import SwiftUI
import UIKit

@MainActor enum TestClock { static var uptime: TimeInterval = 100 }
@MainActor enum TestApplication { static var state: UIApplication.State = .active }
@MainActor enum TestAds {
    enum Mode { case failure, success, suspended }
    static var mode = Mode.failure
    static var continuation: CheckedContinuation<RewardedAd, Error>?
    static var latest: RewardedAd?
    static var presentations = 0
    static var privacyFails = false
}
struct RequestParameters {}
enum OptionsRequirement { case required, notRequired }
@MainActor final class ConsentInformation {
    static let shared = ConsentInformation()
    var canRequestAds: Bool { !TestAds.privacyFails }
    var privacyOptionsRequirementStatus = OptionsRequirement.notRequired
    func requestConsentInfoUpdate(with: RequestParameters) async throws {
        if TestAds.privacyFails { throw AdError.unavailable }
    }
}
@MainActor enum ConsentForm {
    static func loadAndPresentIfRequired(from: UIViewController?) async throws {}
    static func presentPrivacyOptionsForm(from: UIViewController?) async throws {}
}
enum ContentRating { case general }
final class RequestConfiguration {
    var maxAdContentRating = ContentRating.general
    func setPublisherFirstPartyIDEnabled(_ value: Bool) {}
}
@MainActor final class MobileAds {
    static let shared = MobileAds()
    let requestConfiguration = RequestConfiguration()
    func start() async {}
}
final class Extras { var additionalParameters: [String: String] = [:] }
final class Request { func register(_ extras: Extras) {} }
@MainActor protocol FullScreenPresentingAd: AnyObject {}
@MainActor protocol FullScreenContentDelegate: AnyObject {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd)
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error)
}
@MainActor final class RewardedAd: NSObject, FullScreenPresentingAd {
    weak var fullScreenContentDelegate: (any FullScreenContentDelegate)?
    var reward: (() -> Void)?
    static func load(with id: String, request: Request) async throws -> RewardedAd {
        switch TestAds.mode {
        case .failure: throw AdError.unavailable
        case .success:
            let ad = RewardedAd(); TestAds.latest = ad; return ad
        case .suspended:
            return try await withCheckedThrowingContinuation { TestAds.continuation = $0 }
        }
    }
    func canPresent(from: UIViewController?) throws {}
    func present(from: UIViewController?, userDidEarnRewardHandler: @escaping () -> Void) {
        reward = userDidEarnRewardHandler
        TestAds.presentations += 1
    }
}
