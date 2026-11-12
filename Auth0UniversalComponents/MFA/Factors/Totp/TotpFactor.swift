import SwiftUI

/// The code from an authenticator app, as a factor: how it is ordered and worded in the list, the session that runs
/// it, and its screen. It reaches the server only through `TotpTransport`.
@MainActor
struct TotpFactor: MfaFactor {
    let id = MfaFactorID.totp
    /// After push (20): an approval on a registered device can't be phished, a typed code can. Before a phone code
    /// (40): the code never travels over the phone network.
    let rank = 30
    private let transport: TotpTransport

    init(transport: TotpTransport) {
        self.transport = transport
    }

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        let copy = messages.totpChallenge.row
        return MfaFactorRowContent(title: copy.title, subtitle: copy.description, icon: "totp")
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        TotpSession(transport: transport, host: host)
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? TotpChallengeModel).map { AnyView(MfaTotpChallengeScreen(model: $0, messages: messages)) }
    }
}
