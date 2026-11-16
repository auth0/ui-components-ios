import Auth0
import Foundation

/// Guardian push over Embedded Login.
@MainActor
struct EmbeddedPushBinding: EmbeddedFactorBinding {
    /// How the push is polled and resent. Tests shorten it.
    var policy = PushPollingPolicy.default

    var capabilities: [EmbeddedCapability] { [.challengePush, .verifyOob] }

    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer] {
        nextActions.compactMap { action in
            guard case let .challengePush(index, name) = action else { return nil }
            return MfaFactorOffer(id: "push:\(index)", factor: .push, label: name, reference: index)
        }
    }

    func makeFactor(_ services: EmbeddedFactorServices) -> any MfaFactor {
        PushFactor(transport: EmbeddedPushTransport(client: services.client, stager: services.stager,
                                                    gate: services.gate, menu: services.menu), policy: policy)
    }
}

/// `PushTransport` over the Embedded Authorization loop that ran the first factor.
@MainActor
final class EmbeddedPushTransport: PushTransport {
    private let client: EmbeddedAuthClient
    private let stager: EmbeddedMfaStager
    /// Shared with every other factor of this sign-in: a session the user switched away from may still have a check on
    /// its way when the next one sends its push.
    private let gate: EmbeddedRequestGate
    private let menu: ([NextAction]) -> [MfaFactorOffer]

    init(client: EmbeddedAuthClient, stager: EmbeddedMfaStager, gate: EmbeddedRequestGate,
         menu: @escaping ([NextAction]) -> [MfaFactorOffer]) {
        self.client = client
        self.stager = stager
        self.gate = gate
        self.menu = menu
    }

    func sendPush(to offer: MfaFactorOffer) async throws -> PushPending {
        guard let index = offer.reference else { throw MfaError.unexpected(nil) }
        do {
            try await gate.run(challenging: offer.id) { try await client.challengePush(index: index) }
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw EmbeddedMfaErrors.map(error)
            }
            // The push went out when the server asks to check for approval next.
            guard let interval = Self.pollInterval(in: nextActions) else { throw MfaError.unexpected(nil) }
            return PushPending(retryAfterMs: interval, canResend: Self.offersPush(in: nextActions))
        }
        // Success here means the loop closed without an approval step; treat it as an error.
        throw MfaError.unexpected(nil)
    }

    func checkApproval() async throws -> PushCheck {
        do {
            // The server accepted: stage the credentials. The Core says whether the sign-in is still live.
            try stager.stage(try await gate.run { try await client.verifyOob() })
            return .approved
        } catch let error as EmbeddedAuthError {
            return try check(for: error)
        }
    }

    private func check(for error: EmbeddedAuthError) throws -> PushCheck {
        guard case let .insufficientAuthorization(reason, nextActions) = error.reason else {
            throw EmbeddedMfaErrors.map(error)
        }
        let retryAfter = Self.pollInterval(in: nextActions)
        // Every reply says again whether the push can be resent: the server stops offering it at its limit.
        let canResend = Self.offersPush(in: nextActions)
        switch reason {
        case .authorizationPending: return .pending(retryAfterMs: retryAfter, canResend: canResend)
        case .slowDown: return .slowDown(retryAfterMs: retryAfter, canResend: canResend)
        // Approved, and the policy asks for another factor.
        case .none: return .anotherFactor(menu(nextActions))
        // No code or password is sent to a push check.
        case .invalidCode, .invalidIdentifierOrCode, .invalidIdentifierOrPassword: throw MfaError.unexpected(nil)
        @unknown default: throw MfaError.unexpected(nil)
        }
    }

    private static func pollInterval(in nextActions: [NextAction]) -> Int? {
        for case let .verifyOob(pollInMs) in nextActions { return pollInMs }
        return nil
    }

    private static func offersPush(in nextActions: [NextAction]) -> Bool {
        nextActions.contains { if case .challengePush = $0 { return true } else { return false } }
    }
}
