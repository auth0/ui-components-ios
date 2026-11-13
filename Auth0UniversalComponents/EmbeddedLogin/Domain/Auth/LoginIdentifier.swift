import Foundation

/// A way to sign in: what the identifier screen asks for. An email or a phone number is followed by a code or a
/// password, whichever the server offers (see `IdentifierOutcome`); a username is followed by its password.
enum LoginChannel: Hashable, Sendable {
    case email
    case phone
    case password
}

/// What the user typed to sign in. A phone number is in E.164 form (`+14155550123`); a username is as typed.
enum LoginIdentifier: Equatable, Sendable {
    case email(String)
    case phone(String)
    case username(String)

    var value: String {
        switch self {
        case let .email(value), let .phone(value), let .username(value): return value
        }
    }

    var channel: LoginChannel {
        switch self {
        case .email: return .email
        case .phone: return .phone
        case .username: return .password
        }
    }
}
