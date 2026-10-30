import SwiftUI

struct MfaErrorHandler {
    let perform: (MfaError) -> Void
}

private struct MfaErrorHandlerKey: EnvironmentKey {
    static let defaultValue: MfaErrorHandler? = nil
}

extension EnvironmentValues {
    var mfaErrorHandler: MfaErrorHandler? {
        get { self[MfaErrorHandlerKey.self] }
        set { self[MfaErrorHandlerKey.self] = newValue }
    }
}

extension View {
    /// Reports an MFA flow that ended without signing the user in and that the component can't finish, such as
    /// ``MfaError/noEligibleFactors``, so the app can fall back to Universal Login.
    ///
    /// A cancel isn't reported: the user is still inside the login. Handle the cases you care about and ignore
    /// the rest; later releases may add cases, so use `@unknown default`.
    ///
    /// ```swift
    /// EmbeddedLoginView(connection: "email") { session.didSignIn() }
    ///     .onMfaError { error in
    ///         if case .noEligibleFactors = error { router.openUniversalLogin() }
    ///     }
    /// ```
    ///
    /// Without a handler, an account with no usable factor sees a screen saying so.
    public func onMfaError(_ action: @escaping (MfaError) -> Void) -> some View {
        environment(\.mfaErrorHandler, MfaErrorHandler(perform: action))
    }
}
