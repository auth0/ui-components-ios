import Foundation

private func text(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: defaultValue, bundle: ResourceBundle.default)
}

/// The authenticator app factor's copy. Reach it through `MfaMessages.totpChallenge`. It names no app, because a
/// customer may ship its own authenticator.
public struct TotpChallengeMessages: MfaFactorMessages {
    /// How the factor looks in the factor list.
    public var row = MfaHeaderMessage(
        title: text("mfa.authenticatorList.factors.totp.title", "Authenticator app"),
        description: text("mfa.authenticatorList.factors.totp.description",
                          "Enter a code from your authenticator app."))
    /// The first line of text.
    public var title = text("mfa.totpChallenge.title", "Enter the 6-digit code")
    /// The line under the title.
    public var subtitle = text("mfa.totpChallenge.subtitle", "From your authenticator app")
    /// The label above the code boxes.
    public var fieldLabel = text("mfa.totpChallenge.fieldLabel", "One-Time Passcode")
    /// The button that checks the code.
    public var verify = text("mfa.totpChallenge.verify", "Continue")
    /// Under the boxes when the code was wrong.
    public var invalidCode = text("mfa.totpChallenge.invalidCode",
                                  "Invalid Code. Please double check the code in your authenticator app.")
    /// Under the boxes when the connection dropped while the code was being checked.
    public var noConnection = text("mfa.totpChallenge.noConnection",
                                   "No connection. Check your connection and try again.")
    /// The link that goes back to the factor list.
    public var verifyAnotherWay = text("mfa.totpChallenge.verifyAnotherWay", "Verify another way")

    /// Identifies these words inside ``MfaMessages``.
    public static let key = "totpChallenge"
    /// The default words.
    public static var defaults: TotpChallengeMessages { TotpChallengeMessages() }
}

extension MfaMessages {
    /// `$0.totpChallenge.subtitle = "…"`
    public var totpChallenge: TotpChallengeMessages {
        get { self[TotpChallengeMessages.self] }
        set { self[TotpChallengeMessages.self] = newValue }
    }
}
