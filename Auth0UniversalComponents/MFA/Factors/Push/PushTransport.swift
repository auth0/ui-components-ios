import Foundation

/// The server answered that a push is on its way.
struct PushPending: Equatable, Sendable {
    /// Milliseconds to wait before the first check, when the server says.
    var retryAfterMs: Int?
    /// The server still offers this push, so it can be sent again.
    var canResend: Bool
}

/// The answer to one "has the user approved yet?" check.
enum PushCheck: Equatable {
    /// Approved. The transport has already staged the credentials.
    case approved
    /// Not approved yet. `canResend` is whether the server still offers the push, when it says.
    case pending(retryAfterMs: Int?, canResend: Bool? = nil)
    /// Checking too often.
    case slowDown(retryAfterMs: Int?, canResend: Bool? = nil)
    /// Approved, and the policy asks for another factor.
    case anotherFactor([MfaFactorOffer])
}

/// What the push factor needs from a server: send the push, then check whether it was approved.
///
/// Whoever assembles the flow supplies an implementation (Embedded Login has one). Both calls throw `MfaError`.
@MainActor
protocol PushTransport {
    func sendPush(to offer: MfaFactorOffer) async throws -> PushPending
    func checkApproval() async throws -> PushCheck
}
