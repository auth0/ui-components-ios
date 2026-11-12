import SwiftUI

/// Asks for the code from the user's authenticator app: the header, then the shared code entry form, which shows
/// progress on its button while a code is being checked. It is built from the sign-in's code screen pieces, so the two
/// look the same. There is no resend, because the app makes the code, not the server.
public struct MfaTotpChallengeScreen: View {
    let model: TotpChallengeModel
    let messages: MfaMessages

    @Environment(\.auth0Theme) private var theme
    @State private var code = ""
    /// Hides a rejection once the user retypes; the next rejection shows again.
    @State private var isRejectionHidden = false

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - model: What the screen renders and the actions it calls.
    ///   - messages: The words to use.
    public init(model: TotpChallengeModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    private var copy: TotpChallengeMessages { messages.totpChallenge }
    /// What went wrong. A rejection hides once the user retypes; a dropped connection stays until the next check.
    private var problem: String? {
        if model.requestError == .network { return copy.noConnection }
        return model.isCodeRejected && !isRejectionHidden ? copy.invalidCode : nil
    }

    /// The screen.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MfaCodeHeader(title: copy.title, subtitle: copy.subtitle)

            MfaCodeEntryForm(code: $code, digitCount: model.codeLength, fieldLabel: copy.fieldLabel,
                             verifyTitle: copy.verify, isVerifying: model.isVerifying, error: problem,
                             onVerify: { model.submit($0) }, actions: {
                if model.canSwitch {
                    MfaTextButton(copy.verifyAnotherWay, isEnabled: !model.isVerifying) { model.switchFactor() }
                }
            })

            Spacer()
        }
        .mfaScreenChrome(theme: theme)
        .onChangeCompat(of: code) { _ in isRejectionHidden = true }
        .onChangeCompat(of: model.isCodeRejected) { if $0 { isRejectionHidden = false } }
    }
}

#Preview("Code") {
    MfaTotpChallengeScreen(model: TotpChallengeModel())
}

#Preview("Code – another way") {
    MfaTotpChallengeScreen(model: TotpChallengeModel(canSwitch: true))
}

#Preview("Code – verifying") {
    MfaTotpChallengeScreen(model: TotpChallengeModel(isVerifying: true))
}

#Preview("Code – rejected") {
    MfaTotpChallengeScreen(model: TotpChallengeModel(isCodeRejected: true, canSwitch: true))
}

#Preview("Code – no connection") {
    MfaTotpChallengeScreen(model: TotpChallengeModel(requestError: .network))
}
