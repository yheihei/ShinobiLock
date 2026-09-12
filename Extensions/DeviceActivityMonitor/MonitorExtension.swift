import DeviceActivity

final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        ProbeStorage.attempt { try ProbeControl.monitorCallback(activity, kind: "監視区間の開始", forceEnd: false) }
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        ProbeStorage.attempt { try ProbeControl.monitorCallback(activity, kind: "終了前の警告通知", forceEnd: true) }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        ProbeStorage.attempt { try ProbeControl.monitorCallback(activity, kind: "監視区間の終了", forceEnd: true) }
    }
}
