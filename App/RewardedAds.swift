import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform
import UIKit

enum AdConfiguration {
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testUnitID = "ca-app-pub-3940256099942544/1712485313"
    static var appID: String { Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? "" }
    static var unitID: String {
        #if DEBUG
        // Device testing must never generate live ad impressions.
        return testUnitID
        #else
        return Bundle.main.object(forInfoDictionaryKey: "ShinobiRewardedAdUnitID") as? String ?? ""
        #endif
    }
    static var usesTestAds: Bool { unitID == testUnitID }
    static var usesGoogleTestApplication: Bool { appID == testAppID && usesTestAds }
}

@MainActor
final class AdPrivacy: ObservableObject {
    static let shared = AdPrivacy()
    @Published private(set) var optionsRequired = false
    private var updateTask: Task<Void, Error>?

    private init() {}

    func refreshAtLaunch() async {
        do { try await refreshConsentInformation() }
        catch {
            #if DEBUG
            print("Consent update failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func refreshConsentInformation() async throws {
        // Google's shared test application has no publisher consent message configured.
        // A publisher's app ID still uses UMP when displaying test ads.
        if AdConfiguration.usesGoogleTestApplication { return }
        if let updateTask { return try await updateTask.value }
        let task = Task {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
        }
        updateTask = task
        defer {
            updateTask = nil
            updateOptionsRequirement()
        }
        try await task.value
    }

    func prepare() async throws {
        if AdConfiguration.usesGoogleTestApplication { return }
        defer { updateOptionsRequirement() }
        do {
            try await refreshConsentInformation()
            try Task.checkCancellation()
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            if error is CancellationError { throw error }
            // UMP may authorize requests using consent from the previous session.
            guard ConsentInformation.shared.canRequestAds else { throw error }
        }
        guard ConsentInformation.shared.canRequestAds else { throw AdError.unavailable }
    }

    func showOptions() async throws {
        defer { updateOptionsRequirement() }
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }

    private func updateOptionsRequirement() {
        optionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
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
            try await AdPrivacy.shared.prepare()
            try Task.checkCancellation()
            MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
            MobileAds.shared.requestConfiguration.maxAdContentRating = .general
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
