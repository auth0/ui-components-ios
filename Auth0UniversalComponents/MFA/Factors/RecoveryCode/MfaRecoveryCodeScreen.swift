import SwiftUI

/// Typing a recovery code, and then saving the new one. Built from the sign-in's own pieces (header, label, field,
/// button), so it matches the other code screens: no sheet of its own, just the entry.
public struct MfaRecoveryCodeScreen: View {
    let model: RecoveryCodeChallengeModel
    let messages: MfaMessages

    @Environment(\.auth0Theme) private var theme
    @State private var code = ""
    /// What was last sent for checking: a rejection shows only while the field still holds it.
    @State private var submitted = ""
    /// The user ticked that the new code is saved: only then can they go on, so it isn't left unsaved.
    @State private var hasSaved = false

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - model: What the screen renders and the actions it calls.
    ///   - messages: The words to use.
    public init(model: RecoveryCodeChallengeModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    private var copy: RecoveryCodeChallengeMessages { messages.recoveryCodeChallenge }
    private var canSubmit: Bool { !code.cleanedRecoveryCode.isEmpty }

    /// What went wrong: a dropped connection (in the app's words for it), else a wrong code.
    private var problem: String? {
        if model.requestError == .network {
            let network = messages.errors.network
            return "\(network.title) \(network.description)"
        }
        return Self.isRejected(model, code: code, submitted: submitted) ? copy.invalidCode : nil
    }

    static func isRejected(_ model: RecoveryCodeChallengeModel, code: String, submitted: String) -> Bool {
        model.isCodeRejected && code == submitted
    }

    /// The screen.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let newCode = model.newCode {
                save(newCode)
            } else {
                entry
            }
            Spacer()
        }
        .mfaScreenChrome(theme: theme)
        // The code is used up once it is accepted; nothing keeps it.
        .onChangeCompat(of: model.newCode) { if $0 != nil { code = "" } }
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 0) {
            MfaCodeHeader(title: copy.title, subtitle: copy.description)
            MfaSecretField(label: copy.fieldLabel, placeholder: copy.placeholder, text: $code, error: problem,
                           isEnabled: !model.isVerifying, onSubmit: submit)
            MfaPrimaryButton(copy.continueButton, isLoading: model.isVerifying, isEnabled: canSubmit, action: submit)
                .padding(.top, theme.spacing.lg)
            if model.canSwitch {
                MfaTextButton(copy.verifyAnotherWay, isEnabled: !model.isVerifying) { model.switchFactor() }
                    .frame(maxWidth: .infinity)
                    .padding(.top, theme.spacing.lg)
            }
        }
    }

    private func save(_ newCode: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MfaCodeHeader(title: copy.saveTitle, subtitle: copy.saveDescription, subtitleLineLimit: nil)
            MfaCopyField(label: copy.fieldLabel, value: newCode, copiedTitle: copy.copied, copyLabel: copy.copyCode)
            Text(copy.saveHelper)
                .auth0TextStyle(theme.typography.bodySmall)
                .foregroundStyle(theme.colors.text.regular)
                .padding(.top, theme.spacing.xs)
            if model.requestError == .network {
                let network = messages.errors.network
                MfaInlineError("\(network.title) \(network.description)")
                    .padding(.top, theme.spacing.xs)
            }
            MfaCheckbox(title: copy.savedConfirmation, isOn: $hasSaved)
                .padding(.top, theme.spacing.lg)
            MfaPrimaryButton(copy.continueButton, isLoading: model.isVerifying, isEnabled: hasSaved,
                             action: { model.confirm() })
                .padding(.top, theme.spacing.md)
        }
    }

    private func submit() {
        guard canSubmit, !model.isVerifying else { return }
        submitted = code
        model.submit(code)
    }
}

#Preview("Recovery code") {
    MfaRecoveryCodeScreen(model: RecoveryCodeChallengeModel(canSwitch: true))
}

#Preview("Recovery code – rejected") {
    MfaRecoveryCodeScreen(model: RecoveryCodeChallengeModel(isCodeRejected: true, canSwitch: true))
}

#Preview("Recovery code – save the new one") {
    MfaRecoveryCodeScreen(model: RecoveryCodeChallengeModel(newCode: "YHARATFUJJKZNV5N3X1L2ZEC"))
}
