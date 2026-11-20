import Auth0

/// How a one-time code reaches the user. A phone that takes both can be sent a text and called; an email address is
/// only ever emailed.
enum CodeDelivery: CaseIterable, Hashable, Sendable {
    case email
    case text
    case voice

    init(_ method: PhoneDeliveryMethod) {
        switch method {
        case .text: self = .text
        case .voice: self = .voice
        }
    }
}
