import Foundation

struct AccessWindow: Codable, Equatable {
    let startedAt: Date
    let startedUptime: TimeInterval
    var deadline: Date { startedAt.addingTimeInterval(300) }

    func isValid(now: Date, uptime: TimeInterval) -> Bool {
        let wallElapsed = now.timeIntervalSince(startedAt)
        let monotonicElapsed = uptime - startedUptime
        // Clock discontinuities end access early. This is not a reboot-proof clock;
        // the OS callback still needs physical-device testing after a reboot.
        return wallElapsed >= 0 && wallElapsed < 300
            && monotonicElapsed >= 0 && monotonicElapsed < 300
            && abs(wallElapsed - monotonicElapsed) < 5
    }
}
