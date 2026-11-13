import Auth0
import SwiftUI

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
    private let onAuthenticated: @MainActor (Credentials) throws -> Void
    private let mfa: MfaConfiguration
    @StateObject private var additionalStep: EmbeddedMfaStep
    @StateObject private var handOver: CredentialsHandOver
    @Environment(\.mfaErrorHandler) private var mfaErrorHandler

    /// - Parameters:
    ///   - connection: Connection to authorize against. Required; `nil` shows the error screen.
    ///   - preference: Which way leads when the tenant offers both a code and a password for an email or number. The
    ///     default follows the order the tenant lists them in.
    ///   - mfa: Copy, screens and presentation for the MFA steps. The defaults need no configuration.
    ///   - onAuthenticated: Called on the main actor, once, with the credentials as soon as the user is signed in,
    ///     after any additional step. Store them where your app keeps its session, for example with Auth0.swift's
    ///     `CredentialsManager`. If the closure throws, the user sees the "couldn't save" error screen and can start
    ///     again; nothing is kept by the SDK. Call `clear()` on the manager first when replacing an earlier session.
    public init(connection: String? = nil, preference: EmbeddedLoginPreference = .server,
                mfa: MfaConfiguration = MfaConfiguration(),
                onAuthenticated: @escaping @MainActor (Credentials) throws -> Void) {
        self.connection = connection
        self.preference = preference
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
        handOver.handler = onAuthenticated
        return LoginRenderingHostView(
            interactor: Auth0EmbeddedAuthInteractor(credentialsDelivery: handOver, connection: connection,
                                                    preference: preference,
                                                    additionalStepCapabilities: additionalStep.capabilities),
            additionalStep: additionalStep)
    }
}

#Preview {
    NavigationStack { EmbeddedLoginView { _ in } }
}
