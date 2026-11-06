import SwiftUI

/// A code sent to a registered phone, as a factor: how it is ordered and worded in the list, the session that runs
/// it, and its screen. One type serves both deliveries; each instance is made for one, with a transport that sends
/// that way. It reaches the server only through `PhoneCodeTransport`.
@MainActor
struct PhoneCodeFactor: MfaFactor {
    let delivery: PhoneCodeDelivery
    private let transport: PhoneCodeTransport
    private let policy: PhoneCodePolicy

    init(delivery: PhoneCodeDelivery, transport: PhoneCodeTransport, policy: PhoneCodePolicy = .default) {
        self.delivery = delivery
        self.transport = transport
        self.policy = policy
    }

    var id: MfaFactorID {
        switch delivery {
        case .text: return .sms
        case .voice: return .voice
        }
    }

    /// After push (20): a phone code can be phished, an approval on a registered device can't. A text comes before a
    /// call: it can be read when the user can't take a call.
    var rank: Int {
        switch delivery {
        case .text: return 40
        case .voice: return 45
        }
    }

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        let copy = messages.phoneCodeChallenge.copy(for: delivery).row
        // The masked number leads; the kind of factor sits under it.
        return MfaFactorRowContent(title: offer.label ?? copy.title,
                                   subtitle: offer.label == nil ? copy.description : copy.title,
                                   icon: delivery == .text ? "sms" : nil,
                                   // A handset, until the design's own voice icon is in the bundle.
                                   systemImage: delivery == .voice ? "phone" : nil)
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        PhoneCodeSession(offer: offer, delivery: delivery, transport: transport, policy: policy,
                         clock: environment.clock, host: host)
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? PhoneCodeChallengeModel).map { AnyView(MfaPhoneCodeChallengeScreen(model: $0, messages: messages)) }
    }
}
