import Foundation

// Seam over the Auth0 SDK, so the coordinator is testable.

/// A sign-in method advertised by the opening authorize call.
enum LoginOption: Equatable {
    case emailOTP(connection: String)
    /// Advertised but not supported by this flow; ignored by the coordinator.
    case unsupported(String)
}

/// Where the sign-in stands after the email code.
enum AuthProgress: Equatable {
    /// The credentials are already in the Keychain.
    case authenticated
    /// The tenant wants a second factor: Guardian push, sent to one of these devices.
    case guardianPush([GuardianPushDevice])
    /// The tenant wants a second factor this flow can't run (e.g. only SMS), or the user has none it accepts.
    case secondFactorUnavailable
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

/// Sign-in succeeded but the credentials couldn't be saved to the Keychain.
struct CredentialsNotSavedError: LocalizedError, Equatable {
    var errorDescription: String? { "We couldn't save your sign-in on this device. Please try again." }
}

/// Main-actor isolated: implementations keep per-flow loop state.
@MainActor
protocol AuthInteracting {
    /// Opens the embedded authorize loop and returns the methods it advertises.
    func discover() async throws -> [LoginOption]
    /// Sends a one-time code to `email`.
    func startOTP(connection: String, email: String) async throws
    /// `.authenticated` means the credentials are already in the Keychain.
    func verifyOTP(code: String) async throws -> AuthProgress
    /// A push client for the current sign-in; approval stores the credentials before reporting success.
    func makeGuardianPushClient() -> AnyGuardianPushClient<Void>
}
