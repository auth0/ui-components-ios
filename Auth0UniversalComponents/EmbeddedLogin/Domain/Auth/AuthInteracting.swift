import Foundation

// Seam over the Auth0 SDK, so the coordinator is testable.

/// A sign-in method advertised by the opening authorize call.
enum LoginOption: Equatable {
    case emailOTP(connection: String)
    /// Advertised but not supported by this flow; ignored by the coordinator.
    case unsupported(String)
}

/// A factor the server can ask for as an in-loop step-up.
enum MFAFactor: Hashable {
    case otp
    case email
}

/// An in-loop step-up the server requires after the email code.
struct MFAChallenge: Equatable {
    let factor: MFAFactor
    /// Masked destination for the "From …" subtitle, e.g. `s***@atko.email`.
    let destination: String?

    init(factor: MFAFactor, destination: String? = nil) {
        self.factor = factor
        self.destination = destination
    }
}

/// The result of verifying a code. Credentials are stored in the Keychain by the interactor.
enum AuthOutcome: Equatable {
    case authenticated
    case mfaRequired(MFAChallenge)
}

/// Failures shown inline on the current input screen. Any other error goes full-screen.
enum AuthFailure: Error, Equatable {
    case tooManyAttempts
    case invalidCode
    case codeNotSent

    var message: String {
        switch self {
        case .tooManyAttempts: return "Too many attempts. Please try again later."
        case .invalidCode:     return "Invalid Code. Please double check the code sent to your email."
        case .codeNotSent:     return "We couldn't send your code. Please confirm the email address is correct and try again."
        }
    }
}

protocol AuthInteracting {
    /// Opens the embedded authorize loop and returns the methods it advertises.
    func discover() async throws -> [LoginOption]
    /// Sends a one-time code to `email`.
    func startOTP(connection: String, email: String) async throws
    func verifyOTP(code: String) async throws -> AuthOutcome
    func verifyMFA(code: String, factor: MFAFactor) async throws -> AuthOutcome
}
