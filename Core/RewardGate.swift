import Foundation

/// One attempt can complete through an ad reward OR an explicit fallback confirmation.
struct RewardGate {
    enum Phase: Equatable { case idle, loading, presenting, waiting, completed }
    static let fallbackDuration: TimeInterval = 10
    private(set) var attempt: UUID?
    private(set) var phase: Phase = .idle
    private var fallbackStartedAt: TimeInterval?

    mutating func begin() -> UUID {
        let id = UUID()
        attempt = id
        phase = .loading
        fallbackStartedAt = nil
        return id
    }

    func isLoading(_ id: UUID) -> Bool { attempt == id && phase == .loading }

    mutating func present(_ id: UUID) -> Bool {
        guard isLoading(id) else { return false }
        phase = .presenting
        return true
    }

    mutating func claim(_ id: UUID) -> Bool {
        guard attempt == id, phase == .presenting else { return false }
        phase = .completed
        return true
    }

    mutating func offerFallback(_ id: UUID, at uptime: TimeInterval) -> Bool {
        guard attempt == id, phase == .loading || phase == .presenting else { return false }
        phase = .waiting
        fallbackStartedAt = uptime
        return true
    }

    func secondsRemaining(at uptime: TimeInterval) -> Int {
        guard phase == .waiting, let start = fallbackStartedAt else { return 10 }
        return Int(ceil(max(0, Self.fallbackDuration - max(0, uptime - start))))
    }

    mutating func claimFallback(at uptime: TimeInterval) -> Bool {
        guard phase == .waiting, secondsRemaining(at: uptime) == 0 else { return false }
        phase = .completed
        return true
    }

    mutating func finish() {
        attempt = nil
        phase = .idle
        fallbackStartedAt = nil
    }
}
