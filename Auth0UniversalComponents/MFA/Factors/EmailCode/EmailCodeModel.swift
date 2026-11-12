import Foundation

/// Waiting for the code sent to the user's email address.
public struct EmailCodeChallengeModel: MfaFactorModel, Equatable {
    /// The address as the server masked it, e.g. `s***@atko.email`. Empty when the server sent none: the standard
    /// screen then uses ``EmailCodeChallengeMessages/descriptionUnnamed``, and a custom screen should not print an
    /// empty address.
    public let address: String
    /// How many digits the code has.
    public let codeLength: Int
    /// A code was submitted and is being checked: show progress, and don't take another.
    public let isVerifying: Bool
    /// The last code was wrong. Show `messages.emailCodeChallenge.invalidCode`. Cleared when another code is submitted
    /// or sent.
    public let isCodeRejected: Bool
    /// The code timed out. Only a new one helps: checking is off (``submit`` does nothing), and ``resend`` works at
    /// once when ``canResend`` is true. Show `messages.emailCodeChallenge.expiredCode`.
    public let isCodeExpired: Bool
    /// The last request failed but the code in the inbox is still usable, so the screen stays: `.network` when the
    /// connection dropped (submit again or resend), or `.tooManyAttempts` when a new code was refused (try again
    /// later). `nil` otherwise; cleared when the next request starts. Show `messages.emailCodeChallenge.noConnection`
    /// or `.tooManyRequests`.
    public let requestError: MfaError?
    /// Whether the server allows a new code to be sent.
    public let canResend: Bool
    /// Seconds until resend is allowed; 0 when it can be used now. ``canResend`` still says whether the server allows
    /// it at all.
    ///
    /// The flow owns this countdown, so every screen, standard or custom, gets the same wait: calling ``resend``
    /// before it reaches 0 does nothing. The model is published again each second while it counts down. Show it with
    /// `messages.emailCodeChallenge.resend.cooldown(model.resendAvailableIn)`.
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
    ///   - address: The email address as the server masked it.
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
    public init(address: String, codeLength: Int = 6, isVerifying: Bool = false, isCodeRejected: Bool = false,
                isCodeExpired: Bool = false, requestError: MfaError? = nil, canResend: Bool = false,
                resendAvailableIn: Int = 0, canSwitch: Bool = false,
                submit: MfaAction<String> = .init { _ in }, resend: MfaAction<Void> = .none,
                switchFactor: MfaAction<Void> = .none, cancel: MfaAction<Void> = .none) {
        self.address = address
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
    /// Enter a code emailed to a registered address.
    public static let email: MfaFactorID = "email"
}

extension MfaScreens {
    /// The same call shape as the Core's own slots: `MfaScreens(emailCodeChallenge: .custom { model in … })`.
    public init(authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard,
                emailCodeChallenge: MfaScreenSlot<EmailCodeChallengeModel>,
                error: MfaScreenSlot<ErrorModel> = .standard) {
        self.init(authenticatorList: authenticatorList, error: error)
        if case let .custom(build) = emailCodeChallenge.source { self = replacing(.email, with: build) }
    }
}
