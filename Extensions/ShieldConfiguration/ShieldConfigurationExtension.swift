import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // The physical-device probe returned EPERM when this extension tried to
        // write to the App Group. Keep configuration free of persistence or IPC.
        // Configuration calls are not a documented app-open counter either.
        let ink = UIColor(red: 0.13, green: 0.19, blue: 0.18, alpha: 1)
        let paper = UIColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialLight,
            backgroundColor: paper,
            icon: UIImage(systemName: "lock.shield.fill")?.withTintColor(ink, renderingMode: .alwaysOriginal),
            title: .init(text: "忍びロック", color: ink),
            subtitle: .init(text: "\(application.localizedDisplayName ?? "このアプリ")はロックされています。\n大切な時間を、守ろう。", color: ink),
            primaryButtonLabel: .init(text: "閉じる", color: paper),
            primaryButtonBackgroundColor: ink,
            secondaryButtonLabel: .init(text: "広告を見て5分使う", color: ink)
        )
    }
}
