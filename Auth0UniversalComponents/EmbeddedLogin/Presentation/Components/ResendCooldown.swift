import Foundation

/// A resend countdown measured from when it started, so redraws can't slow it down or stall it.
struct ResendCooldown: Equatable {
    /// The wait before a code can be asked for again, wherever it is asked for. `LoginResendButton` is public and
    /// can't name this in its default, so it spells out the same 60.
    static let defaultSeconds = 60

    let seconds: Int
    private(set) var startedAt: Date

    init(seconds: Int, startedAt: Date = Date()) {
        self.seconds = seconds
        self.startedAt = startedAt
    }

    /// Whole seconds left at `date`, rounded up; 0 once it's over.
    func remaining(at date: Date) -> Int {
        Self.remaining(until: startedAt.addingTimeInterval(TimeInterval(seconds)), at: date)
    }

    /// Whole seconds from `date` to `end`, rounded up; 0 once it's over.
    static func remaining(until end: Date, at date: Date) -> Int {
        max(0, Int(end.timeIntervalSince(date).rounded(.up)))
    }

    mutating func restart(at date: Date = Date()) {
        startedAt = date
    }
}
