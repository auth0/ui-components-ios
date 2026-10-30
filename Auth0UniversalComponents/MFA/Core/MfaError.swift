import Foundation

/// Why an MFA flow ended without signing the user in.
///
/// Android has the same cases (`MfaException`). Later releases may add cases, so switch with `@unknown default`.
public enum MfaError: Error, Equatable, Sendable {
    /// The user cancelled. Don't retry.
    case cancelled
    /// The session or token expired.
    case tokenExpired
    /// The session or token is invalid or was already used.
    case tokenInvalid
    /// The server asked for more rounds of verification than ``MfaConfiguration/maximumRounds`` allows (a fourth, by
    /// default).
    case maxChallengesExceeded
    /// The user denied the push.
    case rejected
    /// The server locked the challenge after repeated wrong codes.
    case tooManyAttempts
    /// Nothing this version can verify. Fall back to Universal Login.
    case noEligibleFactors
    /// Step-up was called with no host mounted, or with the app in the background.
    case presentationUnavailable
    /// The request never reached the server. Retrying the same step is safe.
    case network
    /// The user was verified but the credentials couldn't be saved on this device.
    case credentialsNotSaved
    /// Anything else. The message is user-facing text, when there is some.
    case unexpected(String?)

    /// Errors that are already an `MfaError` pass through; a raw `URLError` counts as `.network`.
    /// Anything else carries no text: a transport that has user-facing wording maps its own errors first.
    static func from(_ error: Error) -> MfaError {
        if let known = error as? MfaError { return known }
        if error is URLError { return .network }
        return .unexpected(nil)
    }
}
