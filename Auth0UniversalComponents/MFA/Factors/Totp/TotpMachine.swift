import Foundation

struct TotpState: Equatable {
    enum Phase: Equatable { case idle, awaitingCode, verifying, finished }

    var phase = Phase.idle
    /// The last code was wrong. Cleared when another code is submitted.
    var isCodeRejected = false
    /// The last check never reached the server (`.network`). The code can be typed again. Cleared when the next check
    /// starts.
    var requestError: MfaError?
    /// False once the user moved to another factor: no new requests.
    var isActive = true
}

enum TotpEvent: Equatable {
    case start
    case submit(code: String)
    case verified(TotpVerification)
    /// Checking a code failed (the server never said right or wrong).
    case verifyFailed(MfaError)
    case deactivate
}

enum TotpReport: Equatable {
    case completed
    case anotherFactor([MfaFactorOffer])
    case failed(MfaError)
}

enum TotpEffect: Equatable {
    case verify(code: String)
    case report(TotpReport)
}

/// Every decision the authenticator app factor makes. Pure: no UI, no network, no clock.
enum TotpMachine {
    /// How many digits an authenticator app's code has.
    static let codeLength = 6

    static func reduce(_ old: TotpState, _ event: TotpEvent) -> (TotpState, [TotpEffect]) {
        var state = old
        let effects = state.apply(event)
        return (state, effects)
    }
}

extension TotpState {
    fileprivate mutating func apply(_ event: TotpEvent) -> [TotpEffect] {
        switch event {
        case .start:
            guard phase == .idle, isActive else { return [] }
            phase = .awaitingCode
            return []
        case let .submit(code):
            // Continue is off on the screen until the code is complete; this holds a replaced screen to the same, and
            // keeps one check at a time.
            guard phase == .awaitingCode, isActive, code.count == TotpMachine.codeLength,
                  code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return [] }
            phase = .verifying
            isCodeRejected = false
            requestError = nil
            return [.verify(code: code)]
        case let .verified(answer):
            guard phase == .verifying else { return [] }
            return verified(answer)
        case let .verifyFailed(error):
            guard phase == .verifying else { return [] }
            // A dropped connection leaves the app's code untouched, so the screen stays; anything else, including too
            // many wrong codes (the server locked the challenge), ends the factor.
            guard error == .network else { return finish(.failed(error)) }
            phase = .awaitingCode
            requestError = error
            return []
        case .deactivate:
            isActive = false
            return []
        }
    }

    private mutating func verified(_ answer: TotpVerification) -> [TotpEffect] {
        switch answer {
        case .verified:
            // A verified answer counts even after the user moved to another factor: the server has moved on.
            return finish(.completed)
        case let .anotherFactor(offers):
            return finish(.anotherFactor(offers))
        case .rejected:
            phase = .awaitingCode
            isCodeRejected = true
            return []
        }
    }

    private mutating func finish(_ report: TotpReport) -> [TotpEffect] {
        phase = .finished
        return [.report(report)]
    }
}
