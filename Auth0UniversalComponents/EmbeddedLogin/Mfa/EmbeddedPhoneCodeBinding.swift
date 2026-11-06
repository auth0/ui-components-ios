import Auth0
import Foundation

/// A code sent to a registered phone or email address over Embedded Login: by text message, by a call, or by email.
/// One binding is made per delivery, so the tenant's phones show up once for each way they can take a code.
@MainActor
struct EmbeddedPhoneCodeBinding: EmbeddedFactorBinding {
    let delivery: PhoneCodeDelivery
    /// The code's length and resend wait. Tests shorten it.
    var policy = PhoneCodePolicy.default

    init(delivery: PhoneCodeDelivery, policy: PhoneCodePolicy = .default) {
        self.delivery = delivery
        self.policy = policy
    }

    var capabilities: [EmbeddedCapability] {
        [delivery == .email ? .challengeEmail : .challengePhone, .verifyOTP]
    }

    /// Every phone or address that can take a code this way. A phone the server only calls isn't offered for a text,
    /// and the other way round.
    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer] {
        nextActions.compactMap { action in
            guard let (index, label) = delivery.destination(in: action) else { return nil }
            return MfaFactorOffer(id: "\(delivery.factorID.rawValue):\(index)", factor: delivery.factorID,
                                  label: label, reference: index)
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

    func sendCode(to offer: MfaFactorOffer) async throws -> PhoneCodeSent {
        guard let index = offer.reference else { throw MfaError.unexpected(nil) }
        let delivery = self.delivery
        do {
            try await gate.run { try await delivery.send(to: index, through: client) }
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            // The text, call or email went out when the server asks for the code next.
            guard asksForCode(in: nextActions) else { throw MfaError.unexpected(nil) }
            return PhoneCodeSent(canResend: offersAgain(in: nextActions))
        }
        // Success here means the loop closed without asking for a code; treat it as an error.
        throw MfaError.unexpected(nil)
    }

    func verify(code: String) async throws -> PhoneCodeVerification {
        do {
            // The server accepted: stage the credentials. The Core says whether the sign-in is still live.
            try stager.stage(try await gate.run { try await client.verifyOtp(code, type: .oob) })
            return .verified
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            switch reason {
            // Wrong code: the user can try again, and resend while the server still offers the destination.
            case .invalidCode, .invalidIdentifierOrCode: return .rejected(canResend: offersAgain(in: nextActions))
            // Accepted, and the policy asks for another factor.
            case .none: return .anotherFactor(menu(nextActions))
            // Push answers; a code check never gets them.
            case .authorizationPending, .slowDown: throw MfaError.unexpected(nil)
            @unknown default: throw MfaError.unexpected(nil)
            }
        }
    }

    private func asksForCode(in nextActions: [NextAction]) -> Bool {
        nextActions.contains { if case .verifyOTP(delivery.channel, _) = $0 { return true } else { return false } }
    }

    /// The server still offers to send to a phone (for a text or a call) or to an address (for an email).
    private func offersAgain(in nextActions: [NextAction]) -> Bool {
        nextActions.contains { action in
            switch action {
            case .challengePhone: return delivery != .email
            case .challengeEmail: return delivery == .email
            default: return false
            }
        }
    }
}

private extension PhoneCodeDelivery {
    /// The phone delivery `challengePhone` is asked for. `nil` for an email, which isn't sent through a phone.
    var method: PhoneDeliveryMethod? {
        switch self {
        case .text: return .text
        case .voice: return .voice
        case .email: return nil
        }
    }

    /// The channel the server names when it asks for the code.
    var channel: OtpChannel {
        switch self {
        case .text: return .sms
        case .voice: return .voice
        case .email: return .email
        }
    }

    /// Where `action` offers to send a code this way, if it does: the index to hand back to the server, and the
    /// destination as the screens show it. A phone's mask has its hidden digits as `*`; an address is shown as sent,
    /// since the mask replacement would change a visible `x` in it.
    func destination(in action: NextAction) -> (index: Int, label: String)? {
        switch action {
        case let .challengePhone(index, masked, methods):
            guard let method, methods.contains(method) else { return nil }
            return (index, PhoneMask.display(masked))
        case let .challengeEmail(index, address):
            return self == .email ? (index, address) : nil
        default:
            return nil
        }
    }

    /// Asks the server to send the code.
    func send(to index: Int, through client: EmbeddedAuthClient) async throws {
        if let method {
            try await client.challengePhone(index: index, deliveryMethod: method)
        } else {
            try await client.challengeEmail(index: index)
        }
    }
}
