import SwiftUI

/// A code sent to a registered email address, as a factor: how it is ordered and worded in the list, the session that
/// runs it, and its screen. It reaches the server only through `EmailCodeTransport`.
@MainActor
struct EmailCodeFactor: MfaFactor {
    let id = MfaFactorID.email
    /// After a texted (40) or spoken (45) code. A sign-in that began with an email code makes this a second code to the
    /// same inbox, so it adds the least.
    let rank = 50
    private let transport: EmailCodeTransport
    private let policy: EmailCodePolicy
    /// One for the life of the factor, so every session picks up where the last one left off.
    private let ledger: EmailCodeSendLedger

    init(transport: EmailCodeTransport, policy: EmailCodePolicy = .default, ledger: EmailCodeSendLedger? = nil) {
        self.transport = transport
        self.policy = policy
        self.ledger = ledger ?? EmailCodeSendLedger()
    }

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        let copy = messages.emailCodeChallenge.row
        // The masked address leads; the kind of factor sits under it.
        return MfaFactorRowContent(title: offer.label ?? copy.title,
                                   subtitle: offer.label == nil ? copy.description : copy.title, icon: "email")
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        EmailCodeSession(offer: offer, transport: transport, policy: policy, clock: environment.clock, host: host,
                         ledger: ledger)
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? EmailCodeChallengeModel).map { AnyView(MfaEmailCodeChallengeScreen(model: $0, messages: messages)) }
    }
}
