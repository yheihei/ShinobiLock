import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // The physical-device probe returned EPERM when this extension tried to
        // write to the App Group. Keep configuration free of persistence or IPC.
        // Configuration calls are not a documented app-open counter either.
        let text = UIColor(red: 233 / 255, green: 233 / 255, blue: 237 / 255, alpha: 1)
        let background = UIColor(red: 22 / 255, green: 24 / 255, blue: 38 / 255, alpha: 1)
        let accent = UIColor(red: 210 / 255, green: 206 / 255, blue: 253 / 255, alpha: 1)
        let button = UIColor(red: 121 / 255, green: 108 / 255, blue: 191 / 255, alpha: 1)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: background,
            icon: UIImage(systemName: "lock.shield")?.withTintColor(accent, renderingMode: .alwaysOriginal),
            title: .init(text: "忍びロック", color: text),
            subtitle: .init(text: "\(application.localizedDisplayName ?? "このアプリ")はロックされています。\n大切な時間を、守ろう。", color: text),
            primaryButtonLabel: .init(text: "閉じる", color: text),
            primaryButtonBackgroundColor: button,
            secondaryButtonLabel: .init(text: "広告を見て5分間解除", color: accent)
        )
    }
}
