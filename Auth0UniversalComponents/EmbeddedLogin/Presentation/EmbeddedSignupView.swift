import Auth0
import SwiftUI

/// Embedded sign-up against the tenant in `Auth0.plist`: the user enters their email or phone number, confirms it with
/// a one-time code, and creates the account. The server decides what it asks for and in what order; a connection that
/// needs something this view can't ask for yet shows "Sign-up isn't available".
///
/// The SDK stores nothing. When the account is created, the credentials go to `onAuthenticated`, once, and keeping
/// them is the app's job. If the email or number already has an account, the server signs that user in instead, and
/// `onAuthenticated` is called the same way.
public struct EmbeddedSignupView: View {
    private let connection: String?
    private let onAuthenticated: @MainActor (Credentials) throws -> Void
    @StateObject private var handOver: CredentialsHandOver

    /// - Parameters:
    ///   - connection: Connection to authorize against. Required; `nil` shows the error screen.
    ///   - onAuthenticated: Called on the main actor, once, with the credentials as soon as the account is created.
    ///     If the closure throws, the user sees the "couldn't save" error screen and can start again; nothing is kept
    ///     by the SDK.
    public init(connection: String? = nil,
                onAuthenticated: @escaping @MainActor (Credentials) throws -> Void) {
        self.connection = connection
        self.onAuthenticated = onAuthenticated
        _handOver = StateObject(wrappedValue: CredentialsHandOver(onAuthenticated))
    }

    public var body: some View {
        // Kept current on every update: the app can change its closure after the first appearance.
        handOver.handler = { [onAuthenticated] credentials in try onAuthenticated(credentials) }
        return SignupRenderingHostView(
            interactor: Auth0SignupInteractor(credentialsDelivery: handOver, connection: connection))
    }
}

#Preview {
    NavigationStack { EmbeddedSignupView { _ in } }
}
