import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            ProbeStorage.attempt {
                try ProbeStorage.transaction { $0.record("Shieldの閉じるボタン", application: application) }
            }
            completionHandler(.close)
        case .secondaryButtonPressed:
            do {
                try ProbeStorage.transaction { state in
                    state.pendingUnlockRequest = UnlockRequest(token: application)
                    state.record("Shieldから本体へ移動", application: application)
                }
                completionHandler(.openParentalControlsApp)
            } catch {
                // Do not navigate with a missing or stale target.
                completionHandler(.defer)
            }
        case .firstSecondarySubmenuItemPressed, .secondSecondarySubmenuItemPressed, .thirdSecondarySubmenuItemPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
