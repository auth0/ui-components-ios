import Auth0
import Combine

/// Hands a finished sign-in's credentials to the app that embeds the login. The SDK stores nothing: where the
/// credentials go is the app's decision, and if its handler throws, the sign-in ends as "couldn't be saved".
@MainActor
final class CredentialsHandOver: ObservableObject, CredentialsDelivering {
    typealias Handler = @MainActor (Credentials) throws -> Void

    /// The app's closure. Replaced on every render, so a hand-over always reaches the latest one.
    var handler: Handler

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func deliver(credentials: Credentials) throws {
        try handler(credentials)
    }
}
