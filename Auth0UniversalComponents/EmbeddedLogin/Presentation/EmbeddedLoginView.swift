import SwiftUI

/// Email OTP Embedded Login against the tenant in `Auth0.plist`.
///
/// When the tenant asks for more than the email code, the login hands over to the MFA flow in place. Report flows
/// that can't finish with `onMfaError(_:)`, and brand or replace the MFA screens through `mfa`.
///
/// This view is where the two pieces are put together. The login and the MFA Core don't know each other: the login
/// only has a contract for "an additional step runs here", and `EmbeddedMfaStep` fills it.
public struct EmbeddedLoginView: View {
    private let connection: String?
    private let onAuthenticated: () -> Void
    private let mfa: MfaConfiguration
    @StateObject private var additionalStep: EmbeddedMfaStep
    @Environment(\.mfaErrorHandler) private var mfaErrorHandler

    /// - Parameters:
    ///   - connection: Connection to authorize against. Required; `nil` shows the error screen.
    ///   - mfa: Copy, screens and presentation for the MFA steps. The defaults need no configuration.
    ///   - onAuthenticated: Called on the main actor after credentials are stored in the Keychain.
    public init(connection: String? = nil, mfa: MfaConfiguration = MfaConfiguration(),
                onAuthenticated: @escaping () -> Void = {}) {
        self.connection = connection
        self.onAuthenticated = onAuthenticated
        self.mfa = mfa
        _additionalStep = StateObject(wrappedValue: EmbeddedMfaStep(configuration: mfa))
    }

    /// The sign-in flow. Multi-factor authentication runs in place when the tenant asks for it.
    public var body: some View {
        // Kept current on every update: the app can add, remove or replace `onMfaError`, or change its settings, after
        // the first appearance. Plain properties, so setting them doesn't redraw anything.
        additionalStep.errorHandler = mfaErrorHandler?.perform
        additionalStep.configuration = mfa
        return LoginRenderingHostView(
            interactor: Auth0EmbeddedAuthInteractor(connection: connection,
                                                    additionalStepCapabilities: additionalStep.capabilities),
            additionalStep: additionalStep, onAuthenticated: onAuthenticated)
    }
}

#Preview {
    NavigationStack { EmbeddedLoginView() }
}
