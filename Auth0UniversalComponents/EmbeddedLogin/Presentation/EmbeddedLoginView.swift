import Auth0
import SwiftUI

/// Whether the login's first screen offers to create an account.
public enum EmbeddedLoginSignup: Sendable, Equatable {
    /// The first screen links to sign-up, "Don't have an account? Sign up", when the tenant allows it. The login tells
    /// the server it can send the user to sign-up, so the server offers it next to the sign-in methods.
    case offered
    /// The login is only for signing in, and tells the server nothing about sign-up.
    case hidden
}

/// Embedded Login against the tenant in `Auth0.plist`: an email or phone number with a one-time code or a password,
/// or a username with its password.
///
/// The first screen asks for whichever the tenant lists first, with a button for the other when it offers both. Once
/// it has the email or number, whichever of a code and a password the tenant lists first leads (or the one you pass as
/// `preference`), and the other is one tap away. When the tenant asks for more than the first factor, the login hands
/// over to the MFA flow in place. Report flows
/// that can't finish with `onMfaError(_:)`, and brand or replace the MFA screens through `mfa`.
///
/// The SDK stores nothing. When the user is signed in, the credentials go to `onAuthenticated`, once, and keeping
/// them is the app's job.
///
/// This view is where the two pieces are put together. The login and the MFA Core don't know each other: the login
/// only has a contract for "an additional step runs here", and `EmbeddedMfaStep` fills it.
public struct EmbeddedLoginView: View {
    private let connection: String?
    private let preference: EmbeddedLoginPreference
    private let signup: EmbeddedLoginSignup
    private let onAuthenticated: @MainActor (Credentials) throws -> Void
    private let mfa: MfaConfiguration
    @StateObject private var additionalStep: EmbeddedMfaStep
    @StateObject private var handOver: CredentialsHandOver
    @Environment(\.mfaErrorHandler) private var mfaErrorHandler

    /// - Parameters:
    ///   - connection: Connection to authorize against. Required; `nil` shows the error screen.
    ///   - preference: Which way leads when the tenant offers both a code and a password for an email or number. The
    ///     default follows the order the tenant lists them in.
    ///   - signup: Whether the first screen links to sign-up when the tenant offers it. The default does; pass
    ///     `.hidden` to keep the login to signing in. How the first screen looks is set with `embeddedEntry(_:)`.
    ///   - mfa: Copy, screens and presentation for the MFA steps. The defaults need no configuration.
    ///   - onAuthenticated: Called on the main actor, once, with the credentials as soon as the user is signed in,
    ///     after any additional step. Store them where your app keeps its session, for example with Auth0.swift's
    ///     `CredentialsManager`. If the closure throws, the user sees the "couldn't save" error screen and can start
    ///     again; nothing is kept by the SDK. Call `clear()` on the manager first when replacing an earlier session.
    public init(connection: String? = nil, preference: EmbeddedLoginPreference = .server,
                signup: EmbeddedLoginSignup = .offered, mfa: MfaConfiguration = MfaConfiguration(),
                onAuthenticated: @escaping @MainActor (Credentials) throws -> Void) {
        self.connection = connection
        self.preference = preference
        self.signup = signup
        self.onAuthenticated = onAuthenticated
        self.mfa = mfa
        _additionalStep = StateObject(wrappedValue: EmbeddedMfaStep(configuration: mfa))
        _handOver = StateObject(wrappedValue: CredentialsHandOver(onAuthenticated))
    }

    /// The sign-in flow. Multi-factor authentication runs in place when the tenant asks for it.
    public var body: some View {
        // Kept current on every update: the app can add, remove or replace `onMfaError`, or change its settings, after
        // the first appearance. Plain properties, so setting them doesn't redraw anything.
        additionalStep.errorHandler = mfaErrorHandler?.perform
        additionalStep.configuration = mfa
        handOver.handler = { [onAuthenticated] credentials in try onAuthenticated(credentials) }
        return LoginRenderingHostView(
            interactor: Auth0EmbeddedAuthInteractor(credentialsDelivery: handOver, connection: connection,
                                                    preference: preference,
                                                    additionalStepCapabilities: additionalStep.capabilities,
                                                    offersSignup: signup == .offered),
            additionalStep: additionalStep,
            makeSignup: signup == .offered ? { backToLogin in
                AnyView(SignupRenderingHostView(
                    interactor: Auth0SignupInteractor(credentialsDelivery: handOver, connection: connection),
                    backToLogin: backToLogin))
            } : nil)
    }
}

#Preview {
    NavigationStack { EmbeddedLoginView { _ in } }
}
