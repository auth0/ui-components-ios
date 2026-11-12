import Foundation

/// The answer to one submitted code.
enum TotpVerification: Equatable {
    /// Accepted. The transport has already staged the credentials.
    case verified
    /// The code was wrong; the user can try again.
    case rejected
    /// Accepted, and the policy asks for another factor.
    case anotherFactor([MfaFactorOffer])
}

/// What the authenticator app factor needs from a server: check the code the user read from their app. Nothing is
/// sent first, because the app makes the code, not the server.
///
/// Whoever assembles the flow supplies an implementation (Embedded Login has one). It throws `MfaError`.
@MainActor
protocol TotpTransport {
    /// `isWanted` is asked again if the request has to wait for its turn; when it says no, nothing is sent.
    func verify(code: String, while isWanted: () -> Bool) async throws -> TotpVerification
}
