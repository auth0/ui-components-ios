import Foundation

/// The server answered that a code is on its way, by text message or call.
struct PhoneCodeSent: Equatable, Sendable {
    /// The server still offers this phone, so a new code can be sent.
    var canResend: Bool
}

/// The answer to one submitted code.
enum PhoneCodeVerification: Equatable {
    /// Accepted. The transport has already staged the credentials.
    case verified
    /// The code was wrong; the user can try again. `canResend` is whether the server still offers a new code.
    case rejected(canResend: Bool)
    /// Accepted, and the policy asks for another factor.
    case anotherFactor([MfaFactorOffer])
}

/// What the phone code factor needs from a server: send a code to a phone (texted or spoken in a call, whichever
/// the transport was made for), then check the code the user typed.
///
/// Whoever assembles the flow supplies an implementation (Embedded Login has one). Both calls throw `MfaError`.
@MainActor
protocol PhoneCodeTransport {
    func sendCode(to offer: MfaFactorOffer) async throws -> PhoneCodeSent
    func verify(code: String) async throws -> PhoneCodeVerification
}
