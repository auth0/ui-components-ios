import Foundation

// Seam over the Auth0 SDK, so the coordinator is testable.

/// A sign-in method advertised by the opening authorize call.
enum LoginOption: Equatable {
    case emailOTP(connection: String)
    case phoneOTP(connection: String)
    case password(connection: String)
    /// Advertised but not supported by this flow; ignored by the coordinator.
    case unsupported(String)
}

/// Where the sign-in stands after the one-time code or the password.
enum AuthProgress: Equatable {
    /// The credentials are already with the app.
    case authenticated
    /// The tenant wants more than the first factor. The context carries what an additional step needs to continue the
    /// same sign-in; whatever runs it decides what is usable.
    case additionalStepRequired(AdditionalStepContext)
}

/// What the server asks for once it has the email, phone number or username the user typed. When it offers a code and a
/// password, one leads and the other is the alternative: the one the server lists first, unless the app chose
/// (`EmbeddedLoginPreference`).
enum IdentifierOutcome: Equatable {
    /// A code leads. `startOTP` sends it. `canUsePassword` is whether the server also offers a password.
    case codeOffered(canUsePassword: Bool)
    /// A password leads. `canSendCode` is whether the server also offers a code.
    case passwordOffered(canSendCode: Bool)

    var offersPassword: Bool {
        switch self {
        case .passwordOffered: return true
        case let .codeOffered(canUsePassword): return canUsePassword
        }
    }

    var offersCode: Bool {
        switch self {
        case .codeOffered: return true
        case let .passwordOffered(canSendCode): return canSendCode
        }
    }
}

/// Failures shown inline on the current input screen. Any other error goes full-screen.
enum AuthFailure: Error, Equatable {
    case tooManyAttempts
    case invalidCode
    case codeNotSent
    /// The texted code timed out. Only a new code helps, so the code screen offers Resend straight away.
    case codeExpired
    /// The code was sent for a sign-in the server has since ended (too many wrong codes, a timeout). Only a new code
    /// helps, so the code screen offers Resend straight away.
    case codeNoLongerValid
    /// A password was asked for but the server no longer offers one. Only a code is left.
    case passwordNotAvailable
    /// The server rejected the email, number or username, or the password, and doesn't say which. Also shown when it
    /// offers no password step for a username, so the screen never tells an account that exists from one that doesn't.
    case invalidPassword

    /// Only a new code helps: the one on the screen can't be checked any more.
    var needsNewCode: Bool { self == .codeExpired || self == .codeNoLongerValid }

    /// The words depend on where the code went, or what was typed.
    func message(for channel: LoginChannel) -> String {
        switch self {
        case .tooManyAttempts:
            return "Too many attempts. Please try again later."
        case .codeExpired:
            return "Your code has expired. Resend another code and try again."
        case .codeNoLongerValid:
            return "This code is no longer valid. Please request a new one."
        case .passwordNotAvailable:
            return "A password isn't available for this account. Please use a code instead."
        case .invalidPassword:
            return "Incorrect \(channel.typedThing) or password. Please try again."
        case .invalidCode:
            // A username has no code to check.
            return channel == .password ? Self.somethingWentWrong
                : "Invalid Code. Please double check the code sent to your \(channel == .email ? "email" : "phone")."
        case .codeNotSent:
            let destination = channel == .email ? "email address" : "phone number"
            return channel == .password ? Self.somethingWentWrong
                : "We couldn't send your code. Please confirm the \(destination) is correct and try again."
        }
    }

    private static let somethingWentWrong = "Something went wrong. Please try again."
}

private extension LoginChannel {
    /// What the user typed on the way's first screen, as a sentence names it.
    var typedThing: String {
        switch self {
        case .email: return "email"
        case .phone: return "phone number"
        case .password: return "username"
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
    /// Submits an email address, phone number or username, and says what the server asks for next: a code, a password,
    /// or both with one leading. Nothing is sent to the user: a code is only sent by `startOTP`, which carries on from
    /// here without submitting them again. Throws `AuthFailure.invalidPassword` when a username gets no password step.
    func identify(connection: String, identifier: LoginIdentifier) async throws -> IdentifierOutcome
    /// Sends a one-time code by email or text message. Returns where it went as the server masked it
    /// (e.g. `(4**)***-*900`), when it says; `nil` for an email, which is shown as typed.
    @discardableResult
    func startOTP(connection: String, identifier: LoginIdentifier) async throws -> String?
    /// `.authenticated` means the credentials are already with the app.
    func verifyOTP(code: String) async throws -> AuthProgress
    /// `.authenticated` means the credentials are already with the app.
    func verifyPassword(_ password: String) async throws -> AuthProgress
}
