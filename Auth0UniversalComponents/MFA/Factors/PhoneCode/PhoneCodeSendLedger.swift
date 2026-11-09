import Foundation

/// When a code was last sent to each phone during this sign-in.
///
/// The wait before another code can be sent can't live in a session: the user picks the factor again after "Verify
/// another way", and that is a new session. The factor holds one ledger for all of its sessions, so a phone that was
/// just sent a code is shown that code's screen again instead of being sent another.
@MainActor
final class PhoneCodeSendLedger {
    /// A send that is still inside its wait.
    struct Earlier: Equatable {
        /// Whole seconds left of the wait; always above 0.
        let resendAvailableIn: Int
        /// Whether the server offered another code when that one was sent.
        let canResend: Bool
    }

    private struct Record {
        var sentAt: Date
        var canResend: Bool
    }

    private var records: [String: Record] = [:]
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// A send to this phone is on its way. The wait counts from now, so coming back while it is still in flight is held
    /// back too. It counts even if the send then fails: the phone may have been reached.
    func sending(_ offerID: String) {
        records[offerID] = Record(sentAt: now(), canResend: true)
    }

    /// The server answered the send: the wait counts from now.
    func sent(_ offerID: String, canResend: Bool) {
        records[offerID] = Record(sentAt: now(), canResend: canResend)
    }

    /// The code was used: the next visit to this phone needs a new one.
    func forget(_ offerID: String) {
        records[offerID] = nil
    }

    /// What is left of the wait after the last send to this phone, or `nil` when nothing was sent or the wait is over.
    func earlier(_ offerID: String, cooldownSeconds: Int) -> Earlier? {
        guard cooldownSeconds > 0, let record = records[offerID] else { return nil }
        // A clock set back since then counts as just sent, never as a wait longer than the wait itself.
        let elapsed = max(0, now().timeIntervalSince(record.sentAt))
        let remaining = Int((Double(cooldownSeconds) - elapsed).rounded(.up))
        guard remaining > 0 else { return nil }
        return Earlier(resendAvailableIn: min(remaining, cooldownSeconds), canResend: record.canResend)
    }
}
