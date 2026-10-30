import SwiftUI

/// The push is on its way: names the device, shows progress, and offers resend and "Verify another way".
public struct MfaPushChallengeScreen: View {
    let model: PushChallengeModel
    let messages: MfaMessages

    @Environment(\.auth0Theme) private var theme

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - model: What the screen renders and the actions it calls.
    ///   - messages: The words to use.
    public init(model: PushChallengeModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    private var copy: PushChallengeMessages { messages.pushChallenge }

    /// The screen.
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MfaHeader(title: copy.title, subtitle: copy.description(model.deviceName),
                                   subtitleStyle: MfaStyle.waitingSubtitle,
                                   spacing: MfaStyle.waitingTitleGap)

                VStack(spacing: theme.spacing.sm) {
                    MfaSpinner(diameter: MfaStyle.spinnerDiameter)
                    Text(copy.waiting)
                        .auth0TextStyle(theme.typography.bodySmall)
                        .foregroundStyle(theme.colors.text.regular)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, MfaStyle.spinnerTop)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(copy.waiting), \(model.deviceName)")

                if model.canResend || model.canSwitch {
                    VStack(spacing: theme.spacing.md) {
                        if model.canResend {
                            MfaResendButton(title: copy.resend.button, cooldownTitle: copy.resend.cooldown) {
                                model.resend()
                            }
                        }
                        if model.canSwitch {
                            MfaTextButton(copy.verifyAnotherWay) { model.switchFactor() }
                        }
                    }
                    .padding(.top, MfaStyle.actionsTop)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .mfaScreenChrome(theme: theme, horizontalPadding: theme.spacing.xl,
                              topPadding: MfaStyle.waitingTop)
    }
}

#Preview("Waiting") {
    MfaPushChallengeScreen(model: PushChallengeModel(deviceName: "Sudhanshu's iPhone", canResend: true,
                                                     canSwitch: true))
}

#Preview("Waiting, single device") {
    MfaPushChallengeScreen(model: PushChallengeModel(deviceName: "iPhone"))
}
