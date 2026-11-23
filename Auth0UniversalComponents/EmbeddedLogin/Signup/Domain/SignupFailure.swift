import Auth0

/// Why a sign-up step didn't go through, and what the user can do about it. The first group stays on the screen the
/// user is on, with the message under the field. The second ends the sign-up: only "Start over" follows, because the
/// SDK clears its session on every failure except a continuation or a network error, so another try would find none.
enum SignupFailure: Error, Equatable {
    case invalidEmail
    case invalidCode
    /// The server offered no way to send a code.
    case codeNotSent

    case tooManyAttempts
    case tooManyWrongCodes
    case codeExpired
    case tooManyCodesRequested
    /// Refused before the account existed, for example by a pre-registration Action.
    case denied
    /// Anything else that closed the session, or an answer this flow has no screen for (a second factor after the
    /// account is created, say).
    case ended

    var endsSignup: Bool {
        switch self {
        case .invalidEmail, .invalidCode, .codeNotSent: return false
        case .tooManyAttempts, .tooManyWrongCodes, .codeExpired, .tooManyCodesRequested, .denied, .ended:
            return true
        }
    }

    var message: String {
        switch self {
        case .invalidEmail: return "Please enter a valid email address."
        case .invalidCode: return "Invalid code. Please double check your code that was sent to your email."
        case .codeNotSent:
            return "We couldn't send your code. Please confirm the email address is correct and try again."
        case .tooManyAttempts: return "Too many attempts. Please try again later."
        case .tooManyWrongCodes: return "Too many incorrect codes. Please start again."
        case .codeExpired: return "This code has expired. Please start again."
        case .tooManyCodesRequested: return "Too many codes were requested. Please start again later."
        case .denied: return "We couldn't create your account. Please try again later."
        case .ended: return "We couldn't finish creating your account. Please start again."
        }
    }
}

extension SignupFailure {
    /// Reads the server's answer, and nil when the sign-up goes on. Auth0.swift has no reason of its own for
    /// `invalid_email` (it comes as a plain continuation) or for `too_many_resend_attempts` (it is folded into
    /// `accessDenied`): `error_description` is the only thing that tells them apart, and it is read here and nowhere
    /// else.
    init?(_ error: EmbeddedAuthError) {
        let description = error.info["error_description"] as? String
        guard let failure = Self.fixable(error.reason, description) ?? Self.ending(error.reason, description) else {
            return nil
        }
        self = failure
    }

    /// What the user can fix where they are: the sign-up goes on, with a message under the field.
    private static func fixable(_ reason: EmbeddedAuthErrorReason, _ description: String?) -> SignupFailure? {
        switch (reason, description) {
        case (.insufficientAuthorization(.none, _), "invalid_email"?): return .invalidEmail
        case (.insufficientAuthorization(.invalidCode, _), _),
             (.insufficientAuthorization(.invalidIdentifierOrCode, _), _):
            return .invalidCode
        default: return nil
        }
    }

    /// What ends the sign-up, and nil for what doesn't: the server answered and the flow goes on, or the request
    /// never arrived and the session is still there.
    private static func ending(_ reason: EmbeddedAuthErrorReason, _ description: String?) -> SignupFailure? {
        switch (reason, description) {
        case (.tooManyAttempts, _), (.tooManyLogins, _): return .tooManyAttempts
        case (.tooManyWrongOtpAttempts, _): return .tooManyWrongCodes
        case (.challengeExpired, _): return .codeExpired
        case (.accessDenied, "too_many_resend_attempts"?): return .tooManyCodesRequested
        case (.accessDenied, _): return .denied
        case (.insufficientAuthorization, _), (.network, _): return nil
        default: return .ended
        }
    }
}
