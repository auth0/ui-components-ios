import SwiftUI

// How the sign-up's kinds and codes are drawn with the login's own screens. Adding a kind adds a case here, and the
// compiler asks for it.

extension SignupIdentifierKind {
    /// The login field that collects this kind.
    var channel: LoginChannel {
        switch self {
        case .email: return .email
        case .phone: return .phone
        }
    }
}

extension SignupIdentifierKind {
    /// The title of the screen shown once this kind is verified.
    var verifiedTitle: String {
        switch self {
        case .email: return "Email verified."
        case .phone: return "Phone verified."
        }
    }

    /// What that screen says about it.
    var verifiedMessage: String {
        switch self {
        case .email: return "Your email has been verified."
        case .phone: return "Your phone number has been verified."
        }
    }
}

extension SignupIdentifierValue {
    /// What was typed, as the login's entry screen takes it back.
    var loginIdentifier: LoginIdentifier {
        switch kind {
        case .email: return .email(value)
        case .phone: return .phone(value)
        }
    }
}

extension SignupCodeStep {
    /// Under the title: where the code went. An email shows what was typed; a phone, the number as the server masked
    /// it, and a call says so.
    var subtitle: String {
        let prefix = delivery == .voice ? "Called" : "Sent to"
        return "\(prefix) \(challenge.sentTo ?? identifier.value)"
    }
}
