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
    var canResend = false
    /// Seconds until resend is allowed; 0 when it can be used now. `canResend` says whether the server allows it at
    /// all.
    var resendAvailableIn = 0
    /// The last code was wrong. Cleared when another code is submitted or sent.
    var isCodeRejected = false
    /// False once the user moved to another factor: no timers, no new requests.
    var isActive = true
}

enum PhoneCodeEvent: Equatable {
    case start
    case sent(PhoneCodeSent, epoch: Int)
    case submit(code: String)
    case verified(PhoneCodeVerification, epoch: Int)
    case failed(MfaError, epoch: Int)
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

/// Every decision the phone code factor makes, for a texted code and a spoken one alike. Pure: no UI, no network,
/// no clock.
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
        case let .sent(reply, epoch):
            // `epoch` is 0 until the first code is sent: an answer before that answers nothing.
            guard phase == .sending, epoch == self.epoch, epoch > 0 else { return [] }
            phase = .awaitingCode
            canResend = reply.canResend
            guard isActive else { return [] }
            resendAvailableIn = max(0, policy.resendCooldownSeconds)
            return resendAvailableIn > 0 ? [.scheduleCooldownTick(afterMs: 1_000, epoch: epoch)] : []
        case let .submit(code):
            // Verify is off on the screen until the code is complete; this holds a replaced screen to the same.
            guard phase == .awaitingCode, isActive, code.count == policy.codeLength,
                  code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return [] }
            phase = .verifying
            isCodeRejected = false
            return [.verify(code: code, epoch: epoch)]
        case let .verified(answer, epoch):
            return verified(answer, epoch: epoch)
        case let .failed(error, epoch):
            guard phase != .finished, epoch == self.epoch else { return [] }
            finish()
            return [.report(.failed(error))]
        case let .cooldownTick(seconds, epoch):
            // A tick of a replaced code, or one that arrives after the user left, does nothing.
            guard phase == .awaitingCode || phase == .verifying, epoch == self.epoch, isActive,
                  resendAvailableIn > 0 else { return [] }
            resendAvailableIn = max(0, resendAvailableIn - max(1, seconds))
            return resendAvailableIn > 0 ? [.scheduleCooldownTick(afterMs: 1_000, epoch: epoch)] : []
        case .resend:
            // The countdown is the machine's, not the screen's, so a replaced screen can't resend any faster.
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

    /// Nothing more is sent, checked or offered.
    private mutating func finish() {
        phase = .finished
        canResend = false
        resendAvailableIn = 0
    }
}

// swiftlint:enable cyclomatic_complexity
