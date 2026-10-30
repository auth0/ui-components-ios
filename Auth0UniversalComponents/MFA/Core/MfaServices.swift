import Foundation

/// Stores or discards the credentials a factor has verified. The Core, not the factor, decides when.
///
/// A factor only stages credentials when the server accepts it. `commit` runs when the Core accepts the sign-in while
/// the flow is still live; `abandon` runs when the flow ends without signing in.
@MainActor
protocol MfaCommitter {
    /// Throws `MfaError.credentialsNotSaved` when it can't.
    func commit() throws
    func abandon()
}

/// Waits between steps; injected so tests don't wait.
protocol MfaClock: Sendable {
    func sleep(milliseconds: Int) async throws
}

struct SystemMfaClock: MfaClock {
    func sleep(milliseconds: Int) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }
}
