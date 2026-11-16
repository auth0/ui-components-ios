import Auth0
import Foundation

extension EmbeddedAuthError {
    /// The cause's own description (e.g. "The Internet connection appears to be offline."), else the
    /// server's `error_description`. The SDK's `errorDescription` is debug text and isn't shown.
    /// Reasons the SDK recognises by their `error_description` code get our own copy instead, since that
    /// code (e.g. `too_many_attempts`) isn't user-facing text.
    var displayMessage: String? {
        if let cause { return cause.localizedDescription }
        switch reason {
        case .tooManyWrongOtpAttempts, .tooManyAttempts, .tooManyLogins:
            return "Too many attempts. Please try again later."
        case .ipBlocked:
            return "Sign-in is temporarily blocked. Please try again later."
        case .passwordLeaked:
            return "For your security, this password can't be used because it appeared in a data breach. "
                + "Please reset your password and try again."
        case .consentRequired:
            return "This sign-in needs consent that can't be given in the app."
        case .noActiveSession, .sessionExpired:
            return "Your sign-in timed out. Please try again."
        case .noNextSteps:
            return "We couldn't continue signing you in with this account. Please try again or use another method."
        case .insufficientAuthorization, .noEligibleFactors, .challengeExpired, .authorizationRejected:
            return nil
        default:
            if let description = info["error_description"] as? String, !description.isEmpty { return description }
            return nil
        }
    }
}
