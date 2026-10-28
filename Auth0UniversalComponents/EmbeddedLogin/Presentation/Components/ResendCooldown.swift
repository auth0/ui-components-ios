import Foundation

/// A resend countdown measured from when it started, so redraws can't slow it down or stall it.
struct ResendCooldown: Equatable {
    let seconds: Int
    private(set) var startedAt: Date

    init(seconds: Int, startedAt: Date = Date()) {
        self.seconds = seconds
        self.startedAt = startedAt
    }

    /// Whole seconds left at `date`, rounded up; 0 once it's over.
    func remaining(at date: Date) -> Int {
        let left = startedAt.addingTimeInterval(TimeInterval(seconds)).timeIntervalSince(date)
        return max(0, Int(left.rounded(.up)))
    }

    mutating func restart(at date: Date = Date()) {
        startedAt = date
    }
}
