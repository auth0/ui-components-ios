import Foundation

/// How the first factor reaches the user: what the identifier screen asks for, and where the code is sent.
enum LoginChannel: Hashable, Sendable {
    case email
    case phone
}

/// What the user typed to sign in. A phone number is in E.164 form (`+14155550123`).
enum LoginIdentifier: Equatable, Sendable {
    case email(String)
    case phone(String)

    var value: String {
        switch self {
        case let .email(value), let .phone(value): return value
        }
    }

    var channel: LoginChannel {
        switch self {
        case .email: return .email
        case .phone: return .phone
        }
    }
}
