import Foundation

/// How the code reaches the phone.
public enum PhoneCodeDelivery: String, Sendable, Equatable {
    /// A text message.
    case text
    /// A phone call that reads the code out.
    case voice
}

/// Waiting for the code sent to the user's phone, by text message or by a call.
public struct PhoneCodeChallengeModel: MfaFactorModel, Equatable {
    /// How the code was sent, so a screen can word it ("texted" or "called").
    public let delivery: PhoneCodeDelivery
    /// The phone number as the server masked it, e.g. `(4**)***-*900`, with every masked digit as `*`. Empty when the
    /// server sent none: the standard screen then uses ``PhoneCodeChallengeMessages/Delivery/descriptionUnnamed``, and
    /// a custom screen should not print an empty number.
    public let destination: String
    /// How many digits the code has.
    public let codeLength: Int
    /// A code was submitted and is being checked: show progress, and don't take another.
    public let isVerifying: Bool
    /// The last code was wrong. Show `messages.phoneCodeChallenge.invalidCode`. Cleared when another code is submitted
    /// or sent.
    public let isCodeRejected: Bool
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
    ///   - canResend: Whether the server allows a new code to be sent.
    ///   - resendAvailableIn: Seconds until resend is allowed; 0 when it can be used now.
    ///   - canSwitch: Whether there is another factor to switch to.
    ///   - submit: Checks a code.
    ///   - resend: Sends a new code.
    ///   - switchFactor: Goes back to the factor list.
    ///   - cancel: Ends the flow.
    public init(delivery: PhoneCodeDelivery = .text, destination: String, codeLength: Int = 6,
                isVerifying: Bool = false, isCodeRejected: Bool = false, canResend: Bool = false,
                resendAvailableIn: Int = 0, canSwitch: Bool = false,
                submit: MfaAction<String> = .init { _ in }, resend: MfaAction<Void> = .none,
                switchFactor: MfaAction<Void> = .none, cancel: MfaAction<Void> = .none) {
        self.delivery = delivery
        self.destination = destination
        self.codeLength = codeLength
        self.isVerifying = isVerifying
        self.isCodeRejected = isCodeRejected
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
}

extension MfaScreens {
    /// The same call shape as the Core's own slots: `MfaScreens(phoneCodeChallenge: .custom { model in … })`. The
    /// screen is used for texted and spoken codes alike; read `model.delivery` to tell them apart. To replace more
    /// than one factor's screen, chain ``replacing(_:with:)``.
    public init(authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard,
                phoneCodeChallenge: MfaScreenSlot<PhoneCodeChallengeModel>,
                error: MfaScreenSlot<ErrorModel> = .standard) {
        self.init(authenticatorList: authenticatorList, error: error)
        if case let .custom(build) = phoneCodeChallenge.source {
            self = replacing(.sms, with: build).replacing(.voice, with: build)
        }
    }
}
