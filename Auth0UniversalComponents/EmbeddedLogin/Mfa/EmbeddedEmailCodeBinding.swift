import Auth0
import Foundation

/// A code emailed to a registered address over Embedded Login. Every address the server offers is listed, even one the
/// sign-in's own email code already used: whether that is a second factor is the tenant's policy.
@MainActor
struct EmbeddedEmailCodeBinding: EmbeddedFactorBinding {
    /// The code's length and resend wait. Tests shorten it.
    var policy = EmailCodePolicy.default

    init(policy: EmailCodePolicy = .default) {
        self.policy = policy
    }

    var capabilities: [EmbeddedCapability] { [.challengeEmail, .verifyOTP] }

    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer] {
        nextActions.compactMap { action in
            guard case let .challengeEmail(index, masked) = action else { return nil }
            return MfaFactorOffer(id: "email:\(index)", factor: .email, label: masked, reference: index)
        }
    }

    func makeFactor(_ services: EmbeddedFactorServices) -> any MfaFactor {
        EmailCodeFactor(transport: EmbeddedEmailCodeTransport(client: services.client, stager: services.stager,
                                                              gate: services.gate, menu: services.menu),
                        policy: policy)
    }
}

/// `EmailCodeTransport` over the Embedded Authorization loop that ran the first factor.
@MainActor
final class EmbeddedEmailCodeTransport: EmailCodeTransport {
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

    func sendCode(to offer: MfaFactorOffer, while isWanted: () -> Bool = { true }) async throws -> EmailCodeSent {
        guard let index = offer.reference else { throw MfaError.unexpected(nil) }
        do {
            try await gate.run(challenging: offer.id, while: isWanted) { try await client.challengeEmail(index: index) }
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            // The email went out when the server asks for the code next.
            guard asksForCode(in: nextActions) else { throw MfaError.unexpected(nil) }
            return EmailCodeSent(canResend: stillOffers(offer, in: nextActions))
        }
        // Success here means the loop closed without asking for a code; treat it as an error.
        throw MfaError.unexpected(nil)
    }

    func isCodePending(for offer: MfaFactorOffer) -> Bool { gate.lastChallenge == offer.id }

    func verify(code: String, for offer: MfaFactorOffer, while isWanted: () -> Bool = { true }) async throws
        -> EmailCodeVerification {
        do {
            // The server accepted: stage the credentials. The Core says whether the sign-in is still live.
            try stager.stage(try await gate.run(while: isWanted) { try await client.verifyOtp(code, type: .oob) })
            return .verified
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            switch reason {
            // Wrong code: the user can try again, and resend while the server still offers the address.
            case .invalidCode, .invalidIdentifierOrCode:
                return .rejected(canResend: stillOffers(offer, in: nextActions))
            // Accepted, and the policy asks for another factor.
            case .none: return .anotherFactor(menu(nextActions))
            // Push answers; a code check never gets them.
            case .authorizationPending, .slowDown: throw MfaError.unexpected(nil)
            @unknown default: throw MfaError.unexpected(nil)
            }
        }
    }

    private func asksForCode(in nextActions: [NextAction]) -> Bool {
        nextActions.contains { if case .verifyOTP(.email, _) = $0 { return true } else { return false } }
    }

    /// Resend only for the address the server still offers.
    private func stillOffers(_ offer: MfaFactorOffer, in nextActions: [NextAction]) -> Bool {
        nextActions.contains { action in
            guard case let .challengeEmail(index, _) = action else { return false }
            return index == offer.reference
        }
    }
}
