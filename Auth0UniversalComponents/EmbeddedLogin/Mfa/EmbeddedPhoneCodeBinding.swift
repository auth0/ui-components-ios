import Auth0
import Foundation

/// A code sent to a registered phone over Embedded Login, by text message or by a call. One binding is made per
/// delivery, so the tenant's phones show up once for each way they can take a code.
@MainActor
struct EmbeddedPhoneCodeBinding: EmbeddedFactorBinding {
    let delivery: PhoneCodeDelivery
    /// The code's length and resend wait. Tests shorten it.
    var policy = PhoneCodePolicy.default

    init(delivery: PhoneCodeDelivery, policy: PhoneCodePolicy = .default) {
        self.delivery = delivery
        self.policy = policy
    }

    var capabilities: [EmbeddedCapability] { [.challengePhone, .verifyOTP] }

    /// Every phone that can take a code this way. A phone the server only calls isn't offered for a text, and the
    /// other way round.
    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer] {
        nextActions.compactMap { action in
            guard case let .challengePhone(index, masked, methods) = action, methods.contains(delivery.method) else {
                return nil
            }
            return MfaFactorOffer(id: "\(delivery.factorID.rawValue):\(index)", factor: delivery.factorID,
                                  label: PhoneMask.display(masked), reference: index)
        }
    }

    func makeFactor(_ services: EmbeddedFactorServices) -> any MfaFactor {
        PhoneCodeFactor(delivery: delivery,
                        transport: EmbeddedPhoneCodeTransport(delivery: delivery, client: services.client,
                                                              stager: services.stager, gate: services.gate,
                                                              menu: services.menu),
                        policy: policy)
    }
}

/// `PhoneCodeTransport` over the Embedded Authorization loop that ran the first factor, for one delivery.
@MainActor
final class EmbeddedPhoneCodeTransport: PhoneCodeTransport {
    private let delivery: PhoneCodeDelivery
    private let client: EmbeddedAuthClient
    private let stager: EmbeddedMfaStager
    /// Shared with every other factor of this sign-in: one request at a time.
    private let gate: EmbeddedRequestGate
    private let menu: ([NextAction]) -> [MfaFactorOffer]

    init(delivery: PhoneCodeDelivery, client: EmbeddedAuthClient, stager: EmbeddedMfaStager,
         gate: EmbeddedRequestGate, menu: @escaping ([NextAction]) -> [MfaFactorOffer]) {
        self.delivery = delivery
        self.client = client
        self.stager = stager
        self.gate = gate
        self.menu = menu
    }

    func sendCode(to offer: MfaFactorOffer, while isWanted: () -> Bool = { true }) async throws -> PhoneCodeSent {
        guard let index = offer.reference else { throw MfaError.unexpected(nil) }
        let method = delivery.method
        do {
            try await gate.run(challenging: offer.id, while: isWanted) {
                try await client.challengePhone(index: index, deliveryMethod: method)
            }
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            // The text or call went out when the server asks for the code next.
            guard asksForCode(in: nextActions) else { throw MfaError.unexpected(nil) }
            return PhoneCodeSent(canResend: stillOffers(offer, in: nextActions))
        }
        // Success here means the loop closed without asking for a code; treat it as an error.
        throw MfaError.unexpected(nil)
    }

    func isCodePending(for offer: MfaFactorOffer) -> Bool { gate.lastChallenge == offer.id }

    func verify(code: String, for offer: MfaFactorOffer, while isWanted: () -> Bool = { true }) async throws
        -> PhoneCodeVerification {
        do {
            // The server accepted: stage the credentials. The Core says whether the sign-in is still live.
            try stager.stage(try await gate.run(while: isWanted) { try await client.verifyOtp(code, type: .oob) })
            return .verified
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            switch reason {
            // Wrong code: the user can try again, and resend while the server still offers the phone.
            case .invalidCode, .invalidIdentifierOrCode:
                return .rejected(canResend: stillOffers(offer, in: nextActions))
            // Accepted, and the policy asks for another factor.
            case .none: return .anotherFactor(menu(nextActions))
            // Push and password answers; a code check never gets them.
            case .authorizationPending, .slowDown, .invalidIdentifierOrPassword: throw MfaError.unexpected(nil)
            @unknown default: throw MfaError.unexpected(nil)
            }
        }
    }

    private func asksForCode(in nextActions: [NextAction]) -> Bool {
        nextActions.contains { if case .verifyOTP(delivery.channel, _) = $0 { return true } else { return false } }
    }

    /// Resend only for the pairing the server offers: this phone, by this delivery.
    private func stillOffers(_ offer: MfaFactorOffer, in nextActions: [NextAction]) -> Bool {
        nextActions.contains { action in
            guard case let .challengePhone(index, _, methods) = action else { return false }
            return index == offer.reference && methods.contains(delivery.method)
        }
    }
}

private extension PhoneCodeDelivery {
    /// What `challengePhone` is asked to send.
    var method: PhoneDeliveryMethod {
        switch self {
        case .text: return .text
        case .voice: return .voice
        }
    }

    /// The channel the server names when it asks for the code.
    var channel: OtpChannel {
        switch self {
        case .text: return .sms
        case .voice: return .voice
        }
    }

    var factorID: MfaFactorID {
        switch self {
        case .text: return .sms
        case .voice: return .voice
        }
    }
}
