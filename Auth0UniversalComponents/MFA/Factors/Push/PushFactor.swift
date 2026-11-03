import SwiftUI

/// Guardian push as a factor: how it is ordered and worded in the list, the session that runs it, and its screen.
/// It reaches the server only through `PushTransport`.
@MainActor
struct PushFactor: MfaFactor {
    let id = MfaFactorID.push
    let rank = 20
    private let transport: PushTransport
    private let policy: PushPollingPolicy

    init(transport: PushTransport, policy: PushPollingPolicy = .default) {
        self.transport = transport
        self.policy = policy
    }

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        let copy = messages.pushChallenge.row
        // The device name leads; the kind of factor sits under it.
        return MfaFactorRowContent(title: offer.label ?? copy.title,
                                   subtitle: offer.label == nil ? copy.description : copy.title, icon: "totp")
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        PushSession(offer: offer, transport: transport, policy: policy, clock: environment.clock, host: host)
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? PushChallengeModel).map { AnyView(MfaPushChallengeScreen(model: $0, messages: messages)) }
    }
}
