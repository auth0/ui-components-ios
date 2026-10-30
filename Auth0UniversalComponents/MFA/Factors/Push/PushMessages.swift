import Foundation

private func text(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: defaultValue, bundle: ResourceBundle.default)
}

/// The push factor's copy. Reach it through `MfaMessages.pushChallenge`.
public struct PushChallengeMessages: MfaFactorMessages {
    /// The resend button's words.
    public struct Resend: Sendable {
        /// The button's title when it can be used.
        public var button = text("mfa.pushChallenge.resend.button", "Resend Code")
        /// The button's title while it is counting down. The closure receives the seconds left.
        public var cooldown: @Sendable (_ seconds: Int) -> String = { seconds in
            String(localized: "mfa.pushChallenge.resend.cooldown", defaultValue: "Resend in \(seconds) sec…",
                   bundle: ResourceBundle.default)
        }
    }

    /// How the factor looks in the factor list.
    public var row = MfaHeaderMessage(
        title: text("mfa.authenticatorList.factors.push.title", "Push notification"),
        description: text("mfa.authenticatorList.factors.push.description", "Approve a sign-in request on your phone."))
    /// The first line of text.
    public var title = text("mfa.pushChallenge.title", "Check your device")
    /// The explanation under the title. The closure receives the device's name.
    public var description: @Sendable (_ device: String) -> String = { device in
        String(localized: "mfa.pushChallenge.description",
               defaultValue: "We sent a sign-in request to \(device). Approve it in the Guardian app to continue.",
               bundle: ResourceBundle.default)
    }
    /// Under the spinner, and read out by VoiceOver.
    public var waiting = text("mfa.pushChallenge.waiting", "Waiting for approval")
    /// The resend button's words.
    public var resend = Resend()
    /// The link that goes back to the factor list.
    public var verifyAnotherWay = text("mfa.pushChallenge.verifyAnotherWay", "Verify another way")

    /// Identifies these words inside ``MfaMessages``.
    public static let key = "pushChallenge"
    /// The default words.
    public static var defaults: PushChallengeMessages { PushChallengeMessages() }
}

extension MfaMessages {
    /// `$0.pushChallenge.description = { device in … }`
    public var pushChallenge: PushChallengeMessages {
        get { self[PushChallengeMessages.self] }
        set { self[PushChallengeMessages.self] = newValue }
    }
}
