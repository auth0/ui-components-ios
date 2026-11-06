import SwiftUI

/// The code was texted or is being read out in a call: names the masked number, takes the code, and offers resend
/// and "Verify another way". It is built from the sign-in's code screen pieces, so the two look the same: header, then
/// the shared code entry form.
public struct MfaPhoneCodeChallengeScreen: View {
    let model: PhoneCodeChallengeModel
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
    public init(model: PhoneCodeChallengeModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    private var copy: PhoneCodeChallengeMessages { messages.phoneCodeChallenge }
    private var rejection: String? { model.isCodeRejected && !isRejectionHidden ? copy.invalidCode : nil }

    /// The screen.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MfaCodeHeader(title: copy.title,
                          subtitle: copy.subtitle(number: model.destination, delivery: model.delivery))

            MfaCodeEntryForm(code: $code, digitCount: model.codeLength, fieldLabel: copy.fieldLabel,
                             verifyTitle: copy.verify, isVerifying: model.isVerifying, error: rejection,
                             onVerify: { model.submit($0) }, actions: {
                VStack(spacing: theme.spacing.md) {
                    if model.canResend {
                        MfaResendCodeButton(remaining: model.resendAvailableIn, isBusy: model.isVerifying,
                                            title: copy.resend.button, cooldownTitle: copy.resend.cooldown) {
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
    MfaPhoneCodeChallengeScreen(model: PhoneCodeChallengeModel(destination: "(4**)***-*900", canResend: true,
                                                   resendAvailableIn: 5))
}

#Preview("Code – another way") {
    MfaPhoneCodeChallengeScreen(model: PhoneCodeChallengeModel(destination: "(4**)***-*900", canResend: true,
                                                               canSwitch: true))
}

#Preview("Code – rejected") {
    MfaPhoneCodeChallengeScreen(model: PhoneCodeChallengeModel(destination: "(4**)***-*900", isCodeRejected: true,
                                                   canResend: true, resendAvailableIn: 42, canSwitch: true))
}

#Preview("Voice code") {
    MfaPhoneCodeChallengeScreen(model: PhoneCodeChallengeModel(delivery: .voice, destination: "(4**)***-*900",
                                                               canResend: true, canSwitch: true))
}

#Preview("Code – verifying") {
    MfaPhoneCodeChallengeScreen(model: PhoneCodeChallengeModel(destination: "(4**)***-*900", isVerifying: true,
                                                   canResend: true))
}
