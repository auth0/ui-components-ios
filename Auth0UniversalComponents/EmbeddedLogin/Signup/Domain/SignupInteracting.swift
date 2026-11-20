/// Seam over the Auth0 SDK, so the coordinator is testable. One instance per sign-up: `EmbeddedAuth` is stateful.
@MainActor
protocol SignupInteracting {
    /// Opens a sign-up: `authorize`, then `signup()`. Throws `SignupUnavailable` when the connection offers none this
    /// flow can finish.
    func open() async throws -> SignupMenu
    func identify(_ identifier: SignupIdentifierValue) async throws -> SignupMenu
    /// Sends a code the way given. A code sent again is the same call.
    func sendCode(_ challenge: SignupChallenge, via delivery: CodeDelivery) async throws
    func verify(code: String) async throws -> SignupProgress
    /// Creates the account. The credentials are kept, not handed over: `finish` hands them to the app.
    func confirm() async throws
    /// Hands the credentials of the account `confirm` created to the app, once.
    func finish() async throws
}

/// The connection offers no sign-up this flow can finish.
struct SignupUnavailable: Error, Equatable {}
