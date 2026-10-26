import Foundation

/// How often the push component checks for approval.
public struct GuardianPushPollingPolicy: Equatable, Sendable {
    /// Bounds applied to the server's interval, in milliseconds.
    public var intervalRange: ClosedRange<Int>
    /// The interval when the server doesn't give one, in milliseconds.
    public var defaultInterval: Int
    /// Consecutive network failures tolerated while the app is in the foreground.
    public var maxConsecutiveNetworkFailures: Int

    public init(intervalRange: ClosedRange<Int> = 1_000...60_000,
                defaultInterval: Int = 2_000,
                maxConsecutiveNetworkFailures: Int = 3) {
        self.intervalRange = intervalRange
        self.defaultInterval = defaultInterval
        self.maxConsecutiveNetworkFailures = maxConsecutiveNetworkFailures
    }

    /// 1–60 s bounds, 2 s default, 3 network failures tolerated.
    public static let `default` = GuardianPushPollingPolicy()

    /// The real wait between checks; tests inject their own.
    static func sleep(milliseconds: Int) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }

    /// The first wait, after the push is sent.
    func initialInterval(_ pending: GuardianPushPending) -> Int {
        clamped(pending.retryAfter ?? defaultInterval)
    }

    /// The next wait: the server's interval when given; after `slowDown`, otherwise twice the current one.
    func nextInterval(after check: GuardianPushCheck<some Any>, current: Int) -> Int {
        switch check {
        case .approved: return current
        case let .pending(pending): return clamped(pending.retryAfter ?? current)
        case let .slowDown(pending): return clamped(pending.retryAfter ?? current * 2)
        }
    }

    func clamped(_ milliseconds: Int) -> Int {
        min(max(milliseconds, intervalRange.lowerBound), intervalRange.upperBound)
    }
}
