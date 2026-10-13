import SwiftUI

/// Email OTP Embedded Login against the tenant in `Auth0.plist`.
public struct EmbeddedLoginView: View {
    private let connection: String?
    private let onAuthenticated: () -> Void

    /// - Parameters:
    ///   - connection: Connection to authorize against. Required; `nil` shows the error screen.
    ///   - onAuthenticated: Called on the main actor after credentials are stored in the Keychain.
    public init(connection: String? = nil, onAuthenticated: @escaping () -> Void = {}) {
        self.connection = connection
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        #if AUTH0_EMBEDDED_AUTH
        LoginRenderingHostView(interactor: Auth0EmbeddedAuthInteractor(connection: connection),
                               onAuthenticated: onAuthenticated)
        #else
        EmbeddedLoginUnavailableView()
        #endif
    }
}

#if !AUTH0_EMBEDDED_AUTH
/// Shown when built without `AUTH0_EMBEDDED_AUTH`.
private struct EmbeddedLoginUnavailableView: View {
    var body: some View {
        LoginNoMethodsScreen()
            .navigationTitle("Log in")
            .navigationBarTitleDisplayModeInlineIfAvailable()
    }
}
#endif

#Preview {
    NavigationStack { EmbeddedLoginView() }
}
