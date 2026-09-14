import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform
import UIKit

enum AdConfiguration {
    static let testUnitID = "ca-app-pub-3940256099942544/1712485313"
    static var unitID: String { Bundle.main.object(forInfoDictionaryKey: "ShinobiRewardedAdUnitID") as? String ?? "" }
    static var usesTestAds: Bool { unitID == testUnitID }
}

@MainActor
enum AdPrivacy {
    static var optionsRequired: Bool { ConsentInformation.shared.privacyOptionsRequirementStatus == .required }

    static func prepare() async throws {
        // Google's shared test application has no publisher consent message configured.
        // Only its official test unit can take this path. Real ads always use UMP.
        if AdConfiguration.usesTestAds { return }
        try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
        try await ConsentForm.loadAndPresentIfRequired(from: nil)
        guard ConsentInformation.shared.canRequestAds else { throw AdError.unavailable }
    }

    static func showOptions() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }
}

enum AdError: LocalizedError {
    case unavailable, noLongerLocked
    var errorDescription: String? {
        switch self {
        case .unavailable: return "広告を表示できませんでした。時間をおいて再度お試しください。"
        case .noLongerLocked: return "ロックの状態が変わりました。ホーム画面で確認してください。"
        }
    }
}

@MainActor
final class RewardedAds: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var busy = false
    @Published private(set) var presenting = false
    @Published private(set) var granted = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    private var ad: RewardedAd?
    private var gate = RewardGate()
    private let ineligibleMessage: String
    private let incompleteMessage: String

    init(ineligibleMessage: String = AdError.noLongerLocked.localizedDescription,
         incompleteMessage: String = "広告の視聴が完了していないため、ロックを続けています。") {
        self.ineligibleMessage = ineligibleMessage
        self.incompleteMessage = incompleteMessage
        super.init()
    }

    func show(eligible: @escaping () -> Bool, reward: @escaping () throws -> Void) async {
        guard !busy else { return }
        busy = true
        granted = false
        message = nil
        failed = false
        let attempt = gate.begin()
        do {
            guard eligible() else { throw AdError.noLongerLocked }
            guard !AdConfiguration.unitID.isEmpty else { throw AdError.unavailable }
            try await AdPrivacy.prepare()
            try Task.checkCancellation()
            MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
            await MobileAds.shared.start()
            let request = Request()
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
            let loaded = try await RewardedAd.load(with: AdConfiguration.unitID, request: request)
            try Task.checkCancellation()
            guard eligible(), UIApplication.shared.applicationState == .active else { throw AdError.noLongerLocked }
            ad = loaded
            loaded.fullScreenContentDelegate = self
            try loaded.canPresent(from: nil)
            presenting = true
            loaded.present(from: nil) { [weak self] in
                guard let self, self.gate.claim(attempt) else { return }
                do {
                    guard eligible() else { throw AdError.noLongerLocked }
                    try reward()
                    self.granted = true
                } catch {
                    self.message = (error as? AdError) == .noLongerLocked ? self.ineligibleMessage : error.localizedDescription
                    self.failed = true
                }
            }
        } catch {
            finish()
            if !(error is CancellationError) {
                failed = true
                message = (error as? AdError) == .noLongerLocked ? ineligibleMessage
                    : (error as? AdError)?.localizedDescription ?? AdError.unavailable.localizedDescription
                #if DEBUG
                print("Rewarded ad failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if !granted && message == nil { message = incompleteMessage }
        finish()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        failed = true
        message = AdError.unavailable.localizedDescription
        finish()
    }

    private func finish() {
        gate.finish()
        ad = nil
        presenting = false
        busy = false
    }
}
