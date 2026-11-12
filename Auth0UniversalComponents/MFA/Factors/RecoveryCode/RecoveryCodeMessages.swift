import Foundation

private func localized(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: defaultValue, bundle: ResourceBundle.default)
}

/// The recovery code factor's copy. Reach it through `MfaMessages.recoveryCodeChallenge`.
public struct RecoveryCodeChallengeMessages: MfaFactorMessages {
    /// How the factor looks in the factor list.
    public var row = MfaHeaderMessage(
        title: localized("mfa.authenticatorList.factors.recoveryCode.title", "Recovery code"),
        description: localized("mfa.authenticatorList.factors.recoveryCode.description", "Use your recovery code."))
    /// The first line of text.
    public var title = localized("mfa.recoveryCodeChallenge.title", "Enter the Recovery Code")
    /// The line under the title.
    public var description = localized("mfa.recoveryCodeChallenge.description",
                                       "Please enter your recovery code below.")
    /// The label above the field, for the code being typed and for the new one.
    public var fieldLabel = localized("mfa.recoveryCodeChallenge.fieldLabel", "Recovery Code")
    /// What the empty field says.
    public var placeholder = localized("mfa.recoveryCodeChallenge.placeholder", "Your recovery code")
    /// The button that checks the code, and the one that confirms the new code is saved.
    public var continueButton = localized("mfa.recoveryCodeChallenge.continue", "Continue")
    /// Under the field when the code was wrong.
    public var invalidCode = localized("mfa.recoveryCodeChallenge.invalidCode",
                                       "Invalid recovery code. Please check it and try again.")
    /// The link that goes back to the factor list.
    public var verifyAnotherWay = localized("mfa.recoveryCodeChallenge.verifyAnotherWay", "Verify another way")
    /// The first line of the screen that shows the new code.
    public var saveTitle = localized("mfa.recoveryCodeChallenge.saveTitle", "Save your recovery code")
    /// The line under it.
    public var saveDescription = localized("mfa.recoveryCodeChallenge.saveDescription", """
        This code works only once. Use it to sign in if you lose access to your device
        """)
    /// The small line under the new code.
    public var saveHelper = localized("mfa.recoveryCodeChallenge.saveHelper",
                                      "Store this code somewhere safe, as it won't be shown again")
    /// The checkbox above Continue, which has to be ticked first.
    public var savedConfirmation = localized("mfa.recoveryCodeChallenge.savedConfirmation",
                                             "I have saved this recovery code")
    /// What the bubble over the copy button says.
    public var copied = localized("mfa.recoveryCodeChallenge.copied", "Copied")
    /// What VoiceOver calls the copy button.
    public var copyCode = localized("mfa.recoveryCodeChallenge.copyCode", "Copy recovery code")

    /// Identifies these words inside ``MfaMessages``.
    public static let key = "recoveryCodeChallenge"
    /// The default words.
    public static var defaults: RecoveryCodeChallengeMessages { RecoveryCodeChallengeMessages() }
}

extension MfaMessages {
    /// `$0.recoveryCodeChallenge.title = "…"`
    public var recoveryCodeChallenge: RecoveryCodeChallengeMessages {
        get { self[RecoveryCodeChallengeMessages.self] }
        set { self[RecoveryCodeChallengeMessages.self] = newValue }
    }
}
