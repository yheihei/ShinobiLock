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

    func prepare(beforeConsentForm: () throws -> Void, afterConsentForm: () -> Void) async throws {
        if AdConfiguration.usesGoogleTestApplication { return }
        defer { updateOptionsRequirement() }
        do {
            try await refreshConsentInformation()
            try Task.checkCancellation()
            try beforeConsentForm()
            do {
                defer { afterConsentForm() }
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
            }
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
    @Published private(set) var fallbackEncounter: KarmaEncounter?
    @Published private(set) var fallbackSecondsRemaining = 10
    private var timeoutTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var isEligible: (() -> Bool)?
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
        isEligible = eligible
        let attempt = gate.begin()
        do {
            guard eligible() else { throw AdError.noLongerLocked }
            guard !AdConfiguration.unitID.isEmpty else { throw AdError.unavailable }
            startLoadingTimeout(attempt)
            try await AdPrivacy.shared.prepare(beforeConsentForm: {
                guard self.gate.isLoading(attempt), !Task.isCancelled else { throw CancellationError() }
                self.timeoutTask?.cancel()
            }, afterConsentForm: {
                if self.gate.isLoading(attempt) { self.startLoadingTimeout(attempt) }
            })
            try Task.checkCancellation()
            guard gate.isLoading(attempt) else { return }
            MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
            MobileAds.shared.requestConfiguration.maxAdContentRating = .general
            await MobileAds.shared.start()
            try Task.checkCancellation()
            guard gate.isLoading(attempt) else { return }
            let request = Request()
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
            let loaded = try await RewardedAd.load(with: AdConfiguration.unitID, request: request)
            try Task.checkCancellation()
            guard gate.isLoading(attempt) else { return }
            guard eligible(), UIApplication.shared.applicationState == .active else { throw AdError.noLongerLocked }
            try loaded.canPresent(from: nil)
            guard gate.present(attempt) else { return }
            timeoutTask?.cancel()
            ad = loaded
            loaded.fullScreenContentDelegate = self
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
            // A timed-out or cancelled attempt must not alter a later attempt.
            guard gate.isLoading(attempt) else { return }
            if error is CancellationError || Task.isCancelled {
                cancel()
            } else if (error as? AdError) == .noLongerLocked {
                message = ineligibleMessage
                failed = true
                finish()
            } else {
                print("Rewarded ad unavailable: \(error.localizedDescription)")
                offerFallback(attempt)
            }
        }
    }

    private func startLoadingTimeout(_ attempt: UUID) {
        timeoutTask?.cancel()
        // Bound network/SDK waits. User interaction with a consent form is excluded.
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, self.gate.isLoading(attempt) else { return }
            self.offerFallback(attempt)
        }
    }

    private func offerFallback(_ attempt: UUID) {
        guard gate.offerFallback(attempt, at: ProcessInfo.processInfo.systemUptime) else { return }
        guard isEligible?() == true, UIApplication.shared.applicationState == .active else {
            message = ineligibleMessage
            failed = true
            finish()
            return
        }
        timeoutTask?.cancel()
        ad = nil
        presenting = false
        message = nil
        failed = false
        fallbackSecondsRemaining = 10
        fallbackEncounter = KarmaDialogue.next(context: .adUnavailable)
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.gate.phase == .waiting else { return }
                self.fallbackSecondsRemaining = self.gate.secondsRemaining(at: ProcessInfo.processInfo.systemUptime)
                if self.fallbackSecondsRemaining == 0 { return }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }

    func confirmFallback(eligible: () -> Bool, perform: () throws -> Void) {
        guard UIApplication.shared.applicationState == .active, eligible() else {
            message = ineligibleMessage
            failed = true
            finish()
            return
        }
        guard gate.claimFallback(at: ProcessInfo.processInfo.systemUptime) else { return }
        do {
            try perform()
            granted = true
        } catch {
            message = error.localizedDescription
            failed = true
        }
        finish()
    }

    func cancel() {
        // Presented ads have their own close button and reward callback.
        guard !presenting else { return }
        finish()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard let current = self.ad, current === (ad as AnyObject) else { return }
        if !granted && message == nil { message = incompleteMessage }
        // Closing an ad early never offers the waiting alternative.
        finish()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        guard let current = self.ad, current === (ad as AnyObject), let attempt = gate.attempt else { return }
        print("Rewarded ad presentation failed: \(error.localizedDescription)")
        offerFallback(attempt)
    }

    private func finish() {
        timeoutTask?.cancel()
        countdownTask?.cancel()
        timeoutTask = nil
        countdownTask = nil
        gate.finish()
        fallbackEncounter = nil
        isEligible = nil
        ad = nil
        presenting = false
        busy = false
    }
}
