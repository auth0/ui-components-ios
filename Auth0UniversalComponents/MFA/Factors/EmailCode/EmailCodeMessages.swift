import Foundation

private func text(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: defaultValue, bundle: ResourceBundle.default)
}

/// The email code factor's copy. Reach it through `MfaMessages.emailCodeChallenge`.
public struct EmailCodeChallengeMessages: MfaFactorMessages {
    /// The resend button's words.
    public struct Resend: Sendable {
        /// The button's title when it can be used.
        public var button = text("mfa.emailCodeChallenge.resend.button", "Resend Code")
        /// The button's title while it is counting down. The closure receives the seconds left.
        public var cooldown: @Sendable (_ seconds: Int) -> String = { seconds in
            String(localized: "mfa.emailCodeChallenge.resend.cooldown", defaultValue: "Resend in \(seconds) sec…",
                   bundle: ResourceBundle.default)
        }
    }

    /// How the factor looks in the factor list.
    public var row = MfaHeaderMessage(
        title: text("mfa.authenticatorList.factors.email.title", "Email"),
        description: text("mfa.authenticatorList.factors.email.description", "Get a code by email."))
    /// The first line of text.
    public var title = text("mfa.emailCodeChallenge.title", "Enter the 6-digit code")
    /// The line under the title. The closure receives the address as the server masked it.
    public var description: @Sendable (_ address: String) -> String = { address in
        String(localized: "mfa.emailCodeChallenge.description", defaultValue: "Sent to \(address)",
               bundle: ResourceBundle.default)
    }
    /// The line under the title when the server sent no address, so there is nothing to put in ``description``.
    public var descriptionUnnamed = text("mfa.emailCodeChallenge.descriptionUnnamed", "We emailed you a code.")
    /// The label above the code boxes.
    public var fieldLabel = text("mfa.emailCodeChallenge.fieldLabel", "One-Time Passcode")
    /// The button that checks the code.
    public var verify = text("mfa.emailCodeChallenge.verify", "Verify")
    /// Under the boxes when the code was wrong.
    public var invalidCode = text("mfa.emailCodeChallenge.invalidCode",
                                  "Invalid Code. Please double check the code sent to your email.")
    /// Under the boxes when the code timed out. Verify is off until a new one is sent.
    public var expiredCode = text("mfa.emailCodeChallenge.expiredCode",
                                  "Your code has expired. Resend another code and try again.")
    /// Under the boxes when the connection dropped while a code was being checked or a new one sent. The code in the
    /// inbox still works.
    public var noConnection = text("mfa.emailCodeChallenge.noConnection",
                                   "No connection. Check your connection and try again.")
    /// Under the boxes when a new code was refused because too many were asked for.
    public var tooManyRequests = text("mfa.emailCodeChallenge.tooManyRequests",
                                      "Too many attempts. Please try again later.")
    /// The resend button's words.
    public var resend = Resend()
    /// The link that goes back to the factor list.
    public var verifyAnotherWay = text("mfa.emailCodeChallenge.verifyAnotherWay", "Verify another way")

    /// The line under the title, for an address that may be missing.
    func subtitle(address: String) -> String {
        address.isEmpty ? descriptionUnnamed : description(address)
    }

    /// Identifies these words inside ``MfaMessages``.
    public static let key = "emailCodeChallenge"
    /// The default words.
    public static var defaults: EmailCodeChallengeMessages { EmailCodeChallengeMessages() }
}

extension MfaMessages {
    /// `$0.emailCodeChallenge.row.title = "…"`
    public var emailCodeChallenge: EmailCodeChallengeMessages {
        get { self[EmailCodeChallengeMessages.self] }
        set { self[EmailCodeChallengeMessages.self] = newValue }
    }
}
