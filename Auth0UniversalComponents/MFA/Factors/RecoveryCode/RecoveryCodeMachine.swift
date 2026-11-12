import Foundation

struct RecoveryCodeState: Equatable {
    enum Phase: Equatable { case entering, verifying, saving, confirming, finished }

    var phase = Phase.entering
    /// The code the server issued in place of the one just used. Kept only until the flow ends.
    var newCode: String?
    var isCodeRejected = false
    /// The last request never reached the server: nothing was lost, and the same step can be tried again.
    var requestError: MfaError?
    /// False once the user moved to another factor: no new requests.
    var isActive = true
}

enum RecoveryCodeEvent: Equatable {
    case submit(String)
    case verified(RecoveryCodeVerification)
    case confirm
    case confirmed(RecoveryCodeConfirmation)
    case failed(MfaError)
    case deactivate
}

enum RecoveryCodeReport: Equatable {
    case completed
    case anotherFactor([MfaFactorOffer])
    case failed(MfaError)
}

enum RecoveryCodeEffect: Equatable {
    case verify(String)
    case confirm
    case report(RecoveryCodeReport)
}

extension String {
    /// A code as the user means it. Pasting brings invisible characters along (zero-width spaces, direction marks):
    /// they look like nothing and make the server call the code wrong, so they go, and so does the space around it.
    var cleanedRecoveryCode: String {
        String(String.UnicodeScalarView(unicodeScalars.filter { $0.properties.generalCategory != .format }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Every decision the recovery code factor makes. Pure: no UI, no network.
enum RecoveryCodeMachine {
    static func reduce(_ old: RecoveryCodeState,
                       _ event: RecoveryCodeEvent) -> (RecoveryCodeState, [RecoveryCodeEffect]) {
        var state = old
        let effects = state.apply(event)
        return (state, effects)
    }
}

// swiftlint:disable cyclomatic_complexity

extension RecoveryCodeState {
    fileprivate mutating func apply(_ event: RecoveryCodeEvent) -> [RecoveryCodeEffect] {
        switch event {
        case let .submit(typed):
            let code = typed.cleanedRecoveryCode
            guard phase == .entering, isActive, !code.isEmpty else { return [] }
            phase = .verifying
            isCodeRejected = false
            requestError = nil
            return [.verify(code)]
        case let .verified(answer):
            guard phase == .verifying else { return [] }
            switch answer {
            case let .rotated(code):
                phase = .saving
                newCode = code
            case .rejected:
                phase = .entering
                isCodeRejected = true
            }
            return []
        case .confirm:
            guard phase == .saving, isActive else { return [] }
            phase = .confirming
            requestError = nil
            return [.confirm]
        case let .confirmed(answer):
            guard phase == .confirming else { return [] }
            finish()
            switch answer {
            case .verified: return [.report(.completed)]
            case let .anotherFactor(offers): return [.report(.anotherFactor(offers))]
            }
        case let .failed(error):
            guard phase == .verifying || phase == .confirming else { return [] }
            // Back where the request started, so the same step can be tried again.
            guard error == .network else {
                finish()
                return [.report(.failed(error))]
            }
            phase = phase == .verifying ? .entering : .saving
            requestError = error
            return []
        case .deactivate:
            isActive = false
            return []
        }
    }

    private mutating func finish() {
        phase = .finished
        newCode = nil
    }
}

// swiftlint:enable cyclomatic_complexity
