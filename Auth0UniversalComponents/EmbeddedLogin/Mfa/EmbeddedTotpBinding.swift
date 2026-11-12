import Auth0
import Foundation

/// The code from an authenticator app over Embedded Login. The server lists it as a code to enter, with nothing to send
/// first, so it is offered whenever the menu asks for a code from an authenticator app.
@MainActor
struct EmbeddedTotpBinding: EmbeddedFactorBinding {
    var capabilities: [EmbeddedCapability] { [.verifyOTP] }

    /// One offer when the server asks for an authenticator app's code. The app is the user's, so there is no number or
    /// device name to show.
    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer] {
        let asksForCode = nextActions.contains { action in
            if case .verifyOTP(.totp, _) = action { return true } else { return false }
        }
        return asksForCode ? [MfaFactorOffer(id: "totp", factor: .totp, label: nil)] : []
    }

    func makeFactor(_ services: EmbeddedFactorServices) -> any MfaFactor {
        TotpFactor(transport: EmbeddedTotpTransport(client: services.client, stager: services.stager,
                                                    gate: services.gate, menu: services.menu))
    }
}

/// `TotpTransport` over the Embedded Authorization loop that ran the first factor.
@MainActor
final class EmbeddedTotpTransport: TotpTransport {
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

    func verify(code: String, while isWanted: () -> Bool = { true }) async throws -> TotpVerification {
        do {
            // The server accepted: stage the credentials. The Core says whether the sign-in is still live.
            try stager.stage(try await gate.run(while: isWanted) { try await client.verifyOtp(code, type: .totp) })
            return .verified
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            switch reason {
            // Wrong code: the user can type the app's next one.
            case .invalidCode, .invalidIdentifierOrCode: return .rejected
            // Accepted, and the policy asks for another factor.
            case .none: return .anotherFactor(menu(nextActions))
            // Push answers; a code check never gets them.
            case .authorizationPending, .slowDown: throw MfaError.unexpected(nil)
            @unknown default: throw MfaError.unexpected(nil)
            }
        }
    }
}
