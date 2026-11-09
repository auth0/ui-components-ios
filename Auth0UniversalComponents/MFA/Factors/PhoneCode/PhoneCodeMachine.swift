import Foundation

/// The phone code factor's settings. Tests shorten them.
struct PhoneCodePolicy: Equatable, Sendable {
    /// How many digits a code has.
    var codeLength = 6
    /// Seconds after a code is sent before another can be sent.
    var resendCooldownSeconds = 60

    static let `default` = PhoneCodePolicy()
}

struct PhoneCodeState: Equatable {
    enum Phase: Equatable { case idle, sending, awaitingCode, verifying, finished }

    var phase = Phase.idle
    /// Bumped on every send. A reply carries the epoch it was issued in, so an answer about a code the user replaced
    /// (by resending) can be recognised and dropped. A code's check shares its epoch.
    var epoch = 0
    /// A code is on the phone: one was sent, or the user came back to one sent a moment ago. A failed send only keeps
    /// the screen up when there is one to enter.
    var hasCode = false
    var canResend = false
    /// Seconds until resend is allowed; 0 when it can be used now. `canResend` says whether the server allows it at
    /// all.
    var resendAvailableIn = 0
    /// The last code was wrong. Cleared when another code is submitted or sent.
    var isCodeRejected = false
    /// The code timed out. Only a new one helps: resend is allowed at once and checking is off until one arrives.
    var isCodeExpired = false
    /// The last request failed in a way that leaves the code usable: a dropped connection, or a refused resend
    /// (`.tooManyAttempts`). Cleared when the next request starts.
    var requestError: MfaError?
    /// False once the user moved to another factor: no timers, no new requests.
    var isActive = true
}

enum PhoneCodeEvent: Equatable {
    case start
    /// The user came back to a phone a code was sent to a moment ago: that code is shown again, and no new one goes
    /// out until the wait is over.
    case resume(canResend: Bool, resendAvailableIn: Int)
    case sent(PhoneCodeSent, epoch: Int)
    case submit(code: String)
    case verified(PhoneCodeVerification, epoch: Int)
    /// Sending a code failed.
    case sendFailed(MfaError, epoch: Int)
    /// Checking a code failed (the server never said right or wrong).
    case verifyFailed(MfaError, epoch: Int)
    /// The resend countdown moved on by `seconds`: one, or more when the app was suspended and caught up.
    case cooldownTick(seconds: Int, epoch: Int)
    case resend
    case deactivate
}

enum PhoneCodeReport: Equatable {
    case completed
    case anotherFactor([MfaFactorOffer])
    case failed(MfaError)
}

enum PhoneCodeEffect: Equatable {
    case send(epoch: Int)
    case verify(code: String, epoch: Int)
    /// Wake the resend countdown after `afterMs`; it asks for the next tick itself while it is above 0.
    case scheduleCooldownTick(afterMs: Int, epoch: Int)
    case report(PhoneCodeReport)
}

/// Every decision the phone code factor makes, for a texted code and a spoken one alike. Pure: no UI, no network, no
/// clock.
enum PhoneCodeMachine {
    static func reduce(_ old: PhoneCodeState, _ event: PhoneCodeEvent,
                       policy: PhoneCodePolicy = .default) -> (PhoneCodeState, [PhoneCodeEffect]) {
        var state = old
        let effects = state.apply(event, policy: policy)
        return (state, effects)
    }
}

// swiftlint:disable cyclomatic_complexity

extension PhoneCodeState {
    fileprivate mutating func apply(_ event: PhoneCodeEvent, policy: PhoneCodePolicy) -> [PhoneCodeEffect] {
        switch event {
        case .start:
            guard phase == .idle, isActive else { return [] }
            return send()
        case let .resume(canResend, remaining):
            guard phase == .idle, isActive else { return [] }
            epoch += 1
            phase = .awaitingCode
            hasCode = true
            self.canResend = canResend
            resendAvailableIn = max(0, min(remaining, policy.resendCooldownSeconds))
            return countdown()
        case let .sent(reply, epoch):
            // `epoch` is 0 until the first code is sent: an answer before that answers nothing.
            guard phase == .sending, epoch == self.epoch, epoch > 0 else { return [] }
            phase = .awaitingCode
            hasCode = true
            isCodeExpired = false
            canResend = reply.canResend
            guard isActive else { return [] }
            resendAvailableIn = max(0, policy.resendCooldownSeconds)
            return countdown()
        case let .submit(code):
            // Verify is off on the screen until the code is complete; this holds a replaced screen to the same.
            guard phase == .awaitingCode, isActive, !isCodeExpired, code.count == policy.codeLength,
                  code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return [] }
            phase = .verifying
            isCodeRejected = false
            requestError = nil
            return [.verify(code: code, epoch: epoch)]
        case let .verified(answer, epoch):
            return verified(answer, epoch: epoch)
        case let .sendFailed(error, epoch):
            guard phase == .sending, epoch == self.epoch else { return [] }
            return sendFailed(error, policy: policy)
        case let .verifyFailed(error, epoch):
            guard phase == .verifying, epoch == self.epoch else { return [] }
            return verifyFailed(error)
        case let .cooldownTick(seconds, epoch):
            // A tick of a replaced code, or one that arrives after the user left, does nothing.
            guard phase == .awaitingCode || phase == .verifying, epoch == self.epoch, isActive,
                  resendAvailableIn > 0 else { return [] }
            resendAvailableIn = max(0, resendAvailableIn - max(1, seconds))
            return countdown()
        case .resend:
            // The countdown is the machine's, not the screen's, so a replaced screen can't resend any faster. A code
            // that expired has its wait set to 0, since only a new code helps.
            guard phase == .awaitingCode, canResend, resendAvailableIn == 0, isActive else { return [] }
            isCodeRejected = false
            return send()
        case .deactivate:
            isActive = false
            return []
        }
    }

    private mutating func send() -> [PhoneCodeEffect] {
        epoch += 1
        phase = .sending
        canResend = false
        resendAvailableIn = 0
        requestError = nil
        return [.send(epoch: epoch)]
    }

    private mutating func verified(_ answer: PhoneCodeVerification, epoch: Int) -> [PhoneCodeEffect] {
        guard phase == .verifying, epoch == self.epoch else { return [] }
        switch answer {
        case .verified:
            // A verified answer counts even after the user moved to another factor: the server has moved on.
            finish()
            return [.report(.completed)]
        case let .anotherFactor(offers):
            finish()
            return [.report(.anotherFactor(offers))]
        case let .rejected(canResend):
            phase = .awaitingCode
            isCodeRejected = true
            self.canResend = canResend
            return []
        }
    }

    /// A send that failed. When it was a resend and the code already on the phone is still good, the user stays on
    /// the code screen with the reason; anything else ends the factor.
    ///
    /// - A dropped connection: the session is kept, and the same step can be tried again.
    /// - A rate limit on sending: only the new code is refused; the old one can still be entered.
    private mutating func sendFailed(_ error: MfaError, policy: PhoneCodePolicy) -> [PhoneCodeEffect] {
        guard hasCode, error == .network || error == .tooManyAttempts else { return fail(error) }
        phase = .awaitingCode
        // Resend was allowed, or it could not have been tapped.
        canResend = true
        requestError = error
        // A code that timed out gets no wait; otherwise the next try waits like any other, so a refusal can't be
        // hammered.
        resendAvailableIn = isCodeExpired ? 0 : max(0, policy.resendCooldownSeconds)
        return isActive ? countdown() : []
    }

    /// A check that failed before the server said right or wrong.
    ///
    /// - A dropped connection: the code is untouched, so the same one can be submitted again.
    /// - A timed-out code: a new one fixes it, if the server still offers to send one.
    ///
    /// Anything else, including too many wrong codes (the server locked the challenge), ends the factor.
    private mutating func verifyFailed(_ error: MfaError) -> [PhoneCodeEffect] {
        switch error {
        case .network:
            phase = .awaitingCode
            requestError = error
            return []
        case .tokenExpired where canResend:
            phase = .awaitingCode
            isCodeExpired = true
            requestError = nil
            resendAvailableIn = 0
            return []
        default:
            return fail(error)
        }
    }

    /// The next countdown tick, while there is time left.
    private func countdown() -> [PhoneCodeEffect] {
        resendAvailableIn > 0 ? [.scheduleCooldownTick(afterMs: 1_000, epoch: epoch)] : []
    }

    private mutating func fail(_ error: MfaError) -> [PhoneCodeEffect] {
        finish()
        return [.report(.failed(error))]
    }

    /// Nothing more is sent, checked or offered.
    private mutating func finish() {
        phase = .finished
        canResend = false
        resendAvailableIn = 0
    }
}

// swiftlint:enable cyclomatic_complexity
