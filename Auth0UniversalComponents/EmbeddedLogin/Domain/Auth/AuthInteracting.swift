import Foundation

// Seam over the Auth0 SDK, so the coordinator is testable.

/// A sign-in method advertised by the opening authorize call.
enum LoginOption: Equatable {
    case emailOTP(connection: String)
    case phoneOTP(connection: String)
    /// Advertised but not supported by this flow; ignored by the coordinator.
    case unsupported(String)
}

/// Where the sign-in stands after the one-time code.
enum AuthProgress: Equatable {
    /// The credentials are already with the app.
    case authenticated
    /// The tenant wants more than the first factor. The context carries what an additional step needs to continue the
    /// same sign-in; whatever runs it decides what is usable.
    case additionalStepRequired(AdditionalStepContext)
}

/// Failures shown inline on the current input screen. Any other error goes full-screen.
enum AuthFailure: Error, Equatable {
    case tooManyAttempts
    case invalidCode
    case codeNotSent
    /// The texted code timed out. Only a new code helps, so the code screen offers Resend straight away.
    case codeExpired

    /// The words depend on where the code went.
    func message(for channel: LoginChannel) -> String {
        switch (self, channel) {
        case (.tooManyAttempts, _):
            return "Too many attempts. Please try again later."
        case (.invalidCode, .email):
            return "Invalid Code. Please double check the code sent to your email."
        case (.invalidCode, .phone):
            return "Invalid Code. Please double check the code sent to your phone."
        case (.codeNotSent, .email):
            return "We couldn't send your code. Please confirm the email address is correct and try again."
        case (.codeNotSent, .phone):
            return "We couldn't send your code. Please confirm the phone number is correct and try again."
        case (.codeExpired, _):
            return "Your code has expired. Resend another code and try again."
        }
    }
}

/// Sign-in succeeded but the app couldn't take the credentials (its handler threw).
struct CredentialsNotSavedError: LocalizedError, Equatable {
    var errorDescription: String? { "We couldn't save your sign-in on this device. Please try again." }
}

/// Main-actor isolated: implementations keep per-flow loop state.
@MainActor
protocol AuthInteracting {
    /// Opens the embedded authorize loop and returns the methods it advertises.
    func discover() async throws -> [LoginOption]
    /// Sends a one-time code by email or text message. Returns where it went as the server masked it
    /// (e.g. `(4**)***-*900`), when it says; `nil` for an email, which is shown as typed.
    @discardableResult
    func startOTP(connection: String, identifier: LoginIdentifier) async throws -> String?
    /// `.authenticated` means the credentials are already with the app.
    func verifyOTP(code: String) async throws -> AuthProgress
}
