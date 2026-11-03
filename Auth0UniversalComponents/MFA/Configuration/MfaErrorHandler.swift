import SwiftUI

/// What the app did with an error reported through ``SwiftUICore/View/onMfaError(_:)``.
public enum MfaErrorHandling: Equatable, Sendable {
    /// The app took over and routes the user itself, for example to Universal Login. The SDK shows nothing more for
    /// this error.
    case handled
    /// The app only observed the error, for example to log it. The SDK shows its own screen.
    case notHandled
}

struct MfaErrorHandler {
    let perform: (MfaError) -> MfaErrorHandling
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
    /// Reports an MFA flow that ended without signing the user in, and lets the app take over when the component
    /// can't finish, such as ``MfaError/noEligibleFactors``, so the app can fall back to Universal Login.
    ///
    /// A cancel isn't reported: the user is still inside the login. Handle the cases you care about; later releases
    /// may add cases, so use `@unknown default`.
    ///
    /// Return ``MfaErrorHandling/handled`` only when your app takes over. Only ``MfaError/noEligibleFactors`` depends
    /// on the answer: with `.handled` the SDK shows nothing more and the app must route the user, and with
    /// `.notHandled` the SDK shows its "not available" screen. Every other error already has its own screen with a
    /// way out, so the answer changes nothing for them.
    ///
    /// ```swift
    /// EmbeddedLoginView(connection: "email") { session.didSignIn() }
    ///     .onMfaError { error in
    ///         analytics.log(error)
    ///         if case .noEligibleFactors = error {
    ///             router.openUniversalLogin()
    ///             return .handled
    ///         }
    ///         return .notHandled
    ///     }
    /// ```
    ///
    /// Without a handler, an account with no usable factor sees a screen saying so.
    public func onMfaError(_ action: @escaping (MfaError) -> MfaErrorHandling) -> some View {
        environment(\.mfaErrorHandler, MfaErrorHandler(perform: action))
    }
}
