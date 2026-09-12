import Foundation

/// Only the active ad's first reward callback can authorize a grant.
struct RewardGate {
    private var attempt: UUID?
    private var rewarded = false

    mutating func begin() -> UUID {
        let id = UUID()
        attempt = id
        rewarded = false
        return id
    }

    mutating func claim(_ id: UUID) -> Bool {
        guard attempt == id, !rewarded else { return false }
        rewarded = true
        return true
    }

    mutating func finish() {
        attempt = nil
        rewarded = false
    }
}
