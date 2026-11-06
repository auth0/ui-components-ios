import Foundation

/// Named so it can't be mistaken for the `text` delivery below.
private func localized(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: defaultValue, bundle: ResourceBundle.default)
}

/// The phone code factor's copy, for texted and spoken codes. Reach it through `MfaMessages.phoneCodeChallenge`.
/// What depends on how the code was sent lives under ``text`` and ``voice``; the rest is shared.
public struct PhoneCodeChallengeMessages: MfaFactorMessages {
    /// The words that depend on how the code was sent.
    public struct Delivery: Sendable {
        /// How the factor looks in the factor list.
        public var row: MfaHeaderMessage
        /// The line under the title. The closure receives the phone number as the server masked it.
        public var description: @Sendable (_ number: String) -> String
        /// The line under the title when the server sent no number, so there is nothing to put in ``description``.
        public var descriptionUnnamed: String
    }

    /// The resend button's words.
    public struct Resend: Sendable {
        /// The button's title when it can be used.
        public var button = localized("mfa.phoneCodeChallenge.resend.button", "Resend Code")
        /// The button's title while it is counting down. The closure receives the seconds left.
        public var cooldown: @Sendable (_ seconds: Int) -> String = { seconds in
            String(localized: "mfa.phoneCodeChallenge.resend.cooldown", defaultValue: "Resend in \(seconds) sec…",
                   bundle: ResourceBundle.default)
        }
    }

    /// A code sent by text message.
    public var text = Delivery(
        row: MfaHeaderMessage(
            title: localized("mfa.authenticatorList.factors.sms.title", "Text message"),
            description: localized("mfa.authenticatorList.factors.sms.description", "Get a code by text message.")),
        description: { number in
            String(localized: "mfa.phoneCodeChallenge.text.description", defaultValue: "From \(number)",
                   bundle: ResourceBundle.default)
        },
        descriptionUnnamed: localized("mfa.phoneCodeChallenge.text.descriptionUnnamed",
                                      "We texted a code to your phone."))
    /// A code read out in a phone call.
    public var voice = Delivery(
        row: MfaHeaderMessage(
            title: localized("mfa.authenticatorList.factors.voice.title", "Voice call"),
            description: localized("mfa.authenticatorList.factors.voice.description", "Get a code by phone call.")),
        description: { number in
            String(localized: "mfa.phoneCodeChallenge.voice.description", defaultValue: "Calling \(number)",
                   bundle: ResourceBundle.default)
        },
        descriptionUnnamed: localized("mfa.phoneCodeChallenge.voice.descriptionUnnamed",
                                 "We're calling your phone with a code."))
    /// The first line of text.
    public var title = localized("mfa.phoneCodeChallenge.title", "Enter the 6-digit code")
    /// The label above the code boxes.
    public var fieldLabel = localized("mfa.phoneCodeChallenge.fieldLabel", "One-Time Passcode")
    /// The button that checks the code.
    public var verify = localized("mfa.phoneCodeChallenge.verify", "Verify")
    /// Under the boxes when the code was wrong.
    public var invalidCode = localized("mfa.phoneCodeChallenge.invalidCode",
                                  "Invalid Code. Please double check the code sent to your phone.")
    /// Under the boxes when the code timed out. Verify is off until a new one is sent.
    public var expiredCode = localized("mfa.phoneCodeChallenge.expiredCode",
                                       "Your code has expired. Resend another code and try again.")
    /// Under the boxes when the connection dropped while a code was being checked or a new one sent. The code on the
    /// phone still works.
    public var noConnection = localized("mfa.phoneCodeChallenge.noConnection",
                                        "No connection. Check your connection and try again.")
    /// Under the boxes when a new code was refused because too many were asked for.
    public var tooManyRequests = localized("mfa.phoneCodeChallenge.tooManyRequests",
                                           "Too many attempts. Please try again later.")
    /// The resend button's words.
    public var resend = Resend()
    /// The link that goes back to the factor list.
    public var verifyAnotherWay = localized("mfa.phoneCodeChallenge.verifyAnotherWay", "Verify another way")

    /// The words for one way of sending.
    func copy(for delivery: PhoneCodeDelivery) -> Delivery {
        switch delivery {
        case .text: return text
        case .voice: return voice
        }
    }

    /// The line under the title, for a number that may be missing.
    func subtitle(number: String, delivery: PhoneCodeDelivery) -> String {
        let words = copy(for: delivery)
        return number.isEmpty ? words.descriptionUnnamed : words.description(number)
    }

    /// Identifies these words inside ``MfaMessages``.
    public static let key = "phoneCodeChallenge"
    /// The default words.
    public static var defaults: PhoneCodeChallengeMessages { PhoneCodeChallengeMessages() }
}

extension MfaMessages {
    /// `$0.phoneCodeChallenge.voice.row.title = "…"`
    public var phoneCodeChallenge: PhoneCodeChallengeMessages {
        get { self[PhoneCodeChallengeMessages.self] }
        set { self[PhoneCodeChallengeMessages.self] = newValue }
    }
}
