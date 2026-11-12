import SwiftUI

/// The code was emailed: names the masked address, takes the code, and offers resend and "Verify another way". It is
/// built from the sign-in's code screen pieces, so the two look the same: header, then the shared code entry form,
/// which shows progress on its button while a code is being checked.
public struct MfaEmailCodeChallengeScreen: View {
    let model: EmailCodeChallengeModel
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
    public init(model: EmailCodeChallengeModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    private var copy: EmailCodeChallengeMessages { messages.emailCodeChallenge }
    /// What went wrong, most recent first. A rejection hides once the user retypes; the others stay until the next
    /// request starts, since retyping doesn't fix them.
    private var problem: String? {
        switch model.requestError {
        case .network?: return copy.noConnection
        case .tooManyAttempts?: return copy.tooManyRequests
        default: break
        }
        if model.isCodeExpired { return copy.expiredCode }
        return model.isCodeRejected && !isRejectionHidden ? copy.invalidCode : nil
    }

    /// The screen.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MfaCodeHeader(title: copy.title, subtitle: copy.subtitle(address: model.address))

            MfaCodeEntryForm(code: $code, digitCount: model.codeLength, fieldLabel: copy.fieldLabel,
                             verifyTitle: copy.verify, isVerifying: model.isVerifying, error: problem,
                             canVerify: !model.isCodeExpired, onVerify: { model.submit($0) }, actions: {
                VStack(spacing: theme.spacing.md) {
                    if model.canResend {
                        MfaResendButton(remaining: model.resendAvailableIn, isBusy: model.isVerifying,
                                        title: copy.resend.button, cooldownTitle: copy.resend.cooldown,
                                        look: .text) {
                            // The old code is no use once a new one is on its way.
                            code = ""
                            model.resend()
                        }
                    }
                    if model.canSwitch {
                        MfaTextButton(copy.verifyAnotherWay, isEnabled: !model.isVerifying) { model.switchFactor() }
                    }
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
    MfaEmailCodeChallengeScreen(model: EmailCodeChallengeModel(address: "s***@atko.email", canResend: true,
                                                               resendAvailableIn: 5))
}

#Preview("Code – another way") {
    MfaEmailCodeChallengeScreen(model: EmailCodeChallengeModel(address: "s***@atko.email", canResend: true,
                                                               canSwitch: true))
}

#Preview("Code – rejected") {
    MfaEmailCodeChallengeScreen(model: EmailCodeChallengeModel(address: "s***@atko.email", isCodeRejected: true,
                                                               canResend: true, resendAvailableIn: 42,
                                                               canSwitch: true))
}

#Preview("Code – expired") {
    MfaEmailCodeChallengeScreen(model: EmailCodeChallengeModel(address: "s***@atko.email", isCodeExpired: true,
                                                               canResend: true, canSwitch: true))
}

#Preview("Code – no connection") {
    MfaEmailCodeChallengeScreen(model: EmailCodeChallengeModel(address: "s***@atko.email", requestError: .network,
                                                               canResend: true, resendAvailableIn: 30))
}

#Preview("Code – verifying") {
    MfaEmailCodeChallengeScreen(model: EmailCodeChallengeModel(address: "s***@atko.email", isVerifying: true,
                                                               canResend: true))
}
