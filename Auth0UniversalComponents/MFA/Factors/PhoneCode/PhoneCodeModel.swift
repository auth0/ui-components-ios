import Foundation

/// How the code reaches the user. The factor runs the same way for each; only the words and the row differ.
public enum PhoneCodeDelivery: String, Sendable, Equatable {
    /// A text message.
    case text
    /// A phone call that reads the code out.
    case voice
    /// An email.
    case email

    /// The factor this delivery runs as.
    var factorID: MfaFactorID {
        switch self {
        case .text: return .sms
        case .voice: return .voice
        case .email: return .email
        }
    }
}

/// Waiting for the code sent to the user, by text message, by a call or by email.
public struct PhoneCodeChallengeModel: MfaFactorModel, Equatable {
    /// How the code was sent, so a screen can word it ("texted", "called" or "emailed").
    public let delivery: PhoneCodeDelivery
    /// Where the code went, as the server masked it: a phone number such as `(4**)***-*900` (every masked digit as
    /// `*`), or an email address such as `al**@example.com`. Empty when the server sent none: the standard screen then
    /// uses ``PhoneCodeChallengeMessages/Delivery/descriptionUnnamed``, and a custom screen should not print an empty
    /// value.
    public let destination: String
    /// How many digits the code has.
    public let codeLength: Int
    /// A code was submitted and is being checked: show progress, and don't take another.
    public let isVerifying: Bool
    /// The last code was wrong. Show `invalidCode` from the words for this ``delivery``
    /// (`messages.phoneCodeChallenge.text`, `.voice` or `.email`). Cleared when another code is submitted or sent.
    public let isCodeRejected: Bool
    /// The code timed out. Only a new one helps: checking is off (``submit`` does nothing), and ``resend`` works at
    /// once when ``canResend`` is true. Show `messages.phoneCodeChallenge.expiredCode`.
    public let isCodeExpired: Bool
    /// The last request failed but the code on the phone is still usable, so the screen stays: `.network` when the
    /// connection dropped (submit again or resend), or `.tooManyAttempts` when a new code was refused (try again
    /// later). `nil` otherwise; cleared when the next request starts. Show
    /// `messages.phoneCodeChallenge.noConnection` or `.tooManyRequests`.
    public let requestError: MfaError?
    /// Whether the server allows a new code to be sent.
    public let canResend: Bool
    /// Seconds until resend is allowed; 0 when it can be used now. ``canResend`` still says whether the server allows
    /// it at all.
    ///
    /// The flow owns this countdown, so every screen, standard or custom, gets the same wait: calling ``resend``
    /// before it reaches 0 does nothing. The model is published again each second while it counts down. Show it with
    /// `messages.phoneCodeChallenge.resend.cooldown(model.resendAvailableIn)`.
    public let resendAvailableIn: Int
    /// Whether there is another factor to switch to.
    public let canSwitch: Bool
    /// Checks a code. Pass all ``codeLength`` digits; anything else is ignored.
    public let submit: MfaAction<String>
    /// Sends a new code.
    public let resend: MfaAction<Void>
    /// Goes back to the factor list.
    public let switchFactor: MfaAction<Void>
    /// Ends the flow as cancelled.
    public let cancel: MfaAction<Void>

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - delivery: How the code was sent.
    ///   - destination: The phone number as the server masked it.
    ///   - codeLength: How many digits the code has.
    ///   - isVerifying: Whether a submitted code is being checked.
    ///   - isCodeRejected: Whether the last code was wrong.
    ///   - isCodeExpired: Whether the code timed out.
    ///   - requestError: Why the last request failed, when the screen stays up.
    ///   - canResend: Whether the server allows a new code to be sent.
    ///   - resendAvailableIn: Seconds until resend is allowed; 0 when it can be used now.
    ///   - canSwitch: Whether there is another factor to switch to.
    ///   - submit: Checks a code.
    ///   - resend: Sends a new code.
    ///   - switchFactor: Goes back to the factor list.
    ///   - cancel: Ends the flow.
    public init(delivery: PhoneCodeDelivery = .text, destination: String, codeLength: Int = 6,
                isVerifying: Bool = false, isCodeRejected: Bool = false, isCodeExpired: Bool = false,
                requestError: MfaError? = nil, canResend: Bool = false, resendAvailableIn: Int = 0,
                canSwitch: Bool = false,
                submit: MfaAction<String> = .init { _ in }, resend: MfaAction<Void> = .none,
                switchFactor: MfaAction<Void> = .none, cancel: MfaAction<Void> = .none) {
        self.delivery = delivery
        self.destination = destination
        self.codeLength = codeLength
        self.isVerifying = isVerifying
        self.isCodeRejected = isCodeRejected
        self.isCodeExpired = isCodeExpired
        self.requestError = requestError
        self.canResend = canResend
        self.resendAvailableIn = resendAvailableIn
        self.canSwitch = canSwitch
        self.submit = submit
        self.resend = resend
        self.switchFactor = switchFactor
        self.cancel = cancel
    }
}

extension MfaFactorID {
    /// Enter a code texted to a registered phone.
    public static let sms: MfaFactorID = "sms"
    /// Enter a code read out in a call to a registered phone.
    public static let voice: MfaFactorID = "voice"
    /// Enter a code emailed to a registered address.
    public static let email: MfaFactorID = "email"
}

extension MfaScreens {
    /// The same call shape as the Core's own slots: `MfaScreens(phoneCodeChallenge: .custom { model in … })`. The
    /// screen is used for texted, spoken and emailed codes alike; read `model.delivery` to tell them apart. To
    /// replace more than one factor's screen, chain ``replacing(_:with:)``.
    public init(authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard,
                phoneCodeChallenge: MfaScreenSlot<PhoneCodeChallengeModel>,
                error: MfaScreenSlot<ErrorModel> = .standard) {
        self.init(authenticatorList: authenticatorList, error: error)
        if case let .custom(build) = phoneCodeChallenge.source {
            self = replacing(.sms, with: build).replacing(.voice, with: build).replacing(.email, with: build)
        }
    }
}
