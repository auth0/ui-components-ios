import Auth0
import Foundation

/// A recovery code over Embedded Login. The server offers it as a step with nothing to pick, so there is one offer.
@MainActor
struct EmbeddedRecoveryCodeBinding: EmbeddedFactorBinding {
    var capabilities: [EmbeddedCapability] { [.verifyRecoveryCode, .confirmRecoveryCode] }

    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer] {
        nextActions.contains { if case .verifyRecoveryCode = $0 { return true } else { return false } }
            ? [MfaFactorOffer(id: "recovery_code:0", factor: .recoveryCode, label: nil)]
            : []
    }

    func makeFactor(_ services: EmbeddedFactorServices) -> any MfaFactor {
        RecoveryCodeFactor(transport: EmbeddedRecoveryCodeTransport(client: services.client, stager: services.stager,
                                                                    gate: services.gate, menu: services.menu))
    }
}

/// `RecoveryCodeTransport` over the Embedded Authorization loop that ran the first factor.
@MainActor
final class EmbeddedRecoveryCodeTransport: RecoveryCodeTransport {
    private let client: EmbeddedAuthClient
    private let stager: EmbeddedMfaStager
    /// Shared with every other factor of this sign-in: one request at a time.
    private let gate: EmbeddedRequestGate
    private let menu: ([NextAction]) -> [MfaFactorOffer]

    init(client: EmbeddedAuthClient, stager: EmbeddedMfaStager, gate: EmbeddedRequestGate,
         menu: @escaping ([NextAction]) -> [MfaFactorOffer]) {
        self.client = client
        self.stager = stager
        self.gate = gate
        self.menu = menu
    }

    func verify(code: String, while isWanted: () -> Bool = { true }) async throws -> RecoveryCodeVerification {
        do {
            try await gate.run(while: isWanted) { try await client.verifyRecoveryCode(code) }
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            // Accepted: the server asks for the new code to be confirmed next.
            for case let .confirmRecoveryCode(newCode) in nextActions { return .rotated(newCode: newCode) }
            switch reason {
            case .invalidCode, .invalidIdentifierOrCode: return .rejected
            default: throw MfaError.unexpected(nil)
            }
        }
        // Success here means the loop closed without a new code to save; treat it as an error.
        throw MfaError.unexpected(nil)
    }

    func confirm(while isWanted: () -> Bool = { true }) async throws -> RecoveryCodeConfirmation {
        do {
            // The server accepted: stage the credentials. The Core says whether the sign-in is still live.
            try stager.stage(try await gate.run(while: isWanted) { try await client.confirmRecoveryCode() })
            return .verified
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            // Accepted, and the policy asks for another factor.
            guard case .none = reason else { throw MfaError.unexpected(nil) }
            return .anotherFactor(menu(nextActions))
        }
    }
}
