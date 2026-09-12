import DeviceActivity
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

@main
struct ActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        PickupsReport { configuration in
            PickupsView(configuration: configuration)
        }
    }
}

private struct ApplicationUsage: Identifiable {
    let id = UUID()
    let application: Application
    let pickups: Int
    let seconds: TimeInterval
}

private struct PickupsConfiguration {
    var applications: [ApplicationUsage] = []
    var lastUpdated: Date?
}

private struct PickupsReport: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("ShinobiLock.Pickups")
    let content: (PickupsConfiguration) -> PickupsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> PickupsConfiguration {
        var result = PickupsConfiguration()
        // Render only the data supplied by the app's selected-application filter.
        // Report data remains inside this extension: no shared files or IPC.
        for await device in data {
            result.lastUpdated = max(result.lastUpdated ?? .distantPast, device.lastUpdatedDate)
            for await segment in device.activitySegments {
                for await category in segment.categories {
                    for await activity in category.applications {
                        result.applications.append(ApplicationUsage(application: activity.application,
                                                                    pickups: activity.numberOfPickups,
                                                                    seconds: activity.totalActivityDuration))
                    }
                }
            }
        }
        result.applications.sort { $0.seconds > $1.seconds }
        return result
    }
}

private struct PickupsView: View {
    let configuration: PickupsConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("今日のScreen Time統計").font(.title2.bold())
                Text("端末を起こした後、最初に使ったアプリの回数です。アプリを開くたびの回数や、ロック画面の表示回数とは異なります。")
                    .font(.subheadline).foregroundStyle(.secondary)
                if configuration.applications.isEmpty {
                    Text("選択したアプリの統計がまだ届いていません。0回と確定した状態ではありません。")
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                }
                ForEach(configuration.applications) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        if let token = item.application.token {
                            Label(token).labelStyle(.titleAndIcon)
                        } else {
                            Text(item.application.localizedDisplayName ?? "選択したアプリ")
                        }
                        LabeledContent("持ち上げ後に最初に使用", value: "\(item.pickups)回")
                        LabeledContent("利用時間", value: duration(item.seconds))
                    }
                    .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                }
                if let date = configuration.lastUpdated {
                    Text("OSの更新日時: \(date.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("OSの統計には反映待ちが発生します。この画面の数値は試作の操作ログには保存しません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.90))
        .preferredColorScheme(.light)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return "\(total / 60)分\(total % 60)秒"
    }
}
