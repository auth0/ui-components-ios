import SwiftUI

/// A recovery code, as a factor: how it is ordered and worded in the list, the session that runs it, and its screen. It
/// reaches the server only through `RecoveryCodeTransport`.
@MainActor
struct RecoveryCodeFactor: MfaFactor {
    let id = MfaFactorID.recoveryCode
    /// Last: it is the way in when nothing else is at hand, and using it replaces the code.
    let rank = 90
    private let transport: RecoveryCodeTransport

    init(transport: RecoveryCodeTransport) {
        self.transport = transport
    }

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        let copy = messages.recoveryCodeChallenge.row
        return MfaFactorRowContent(title: copy.title, subtitle: copy.description, icon: "code")
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        RecoveryCodeSession(transport: transport, host: host)
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? RecoveryCodeChallengeModel).map { AnyView(MfaRecoveryCodeScreen(model: $0, messages: messages)) }
    }
}
