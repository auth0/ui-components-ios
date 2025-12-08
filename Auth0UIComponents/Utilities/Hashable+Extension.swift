import SwiftUI
import Combine
import Foundation
import Auth0

enum Route: Hashable {
    case enrollPasskeyScreen

    case emailPhoneEnrollmentScreen(type: AuthMethodType)
    case totpPushQRScreen(type: AuthMethodType)
    case recoveryCodeScreen
    case otpScreen(type: AuthMethodType,
                   emailOrPhoneNumber: String? = nil,
                   totpEnrollmentChallege: TOTPEnrollmentChallenge? = nil,
                   phoneEnrollmentChallenge: PhoneEnrollmentChallenge? = nil,
                   emailEnrollmentChallenge: EmailEnrollmentChallenge? = nil)
    case filteredAuthListScreen(type: AuthMethodType,
                                authMethods: [AuthenticationMethod])
}

extension AuthMethodType: Hashable {
    
}

extension TOTPEnrollmentChallenge: @retroactive Hashable {
    public static func == (lhs: TOTPEnrollmentChallenge, rhs: TOTPEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

extension PhoneEnrollmentChallenge: @retroactive Hashable {
    public static func == (lhs: PhoneEnrollmentChallenge, rhs: PhoneEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

extension EmailEnrollmentChallenge: @retroactive Hashable {
    public static func == (lhs: EmailEnrollmentChallenge, rhs: EmailEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

struct AnyTokenProvider: Hashable {
    private let base: any TokenProvider
    private let _hash: (inout Hasher) -> Void
    private let _equals: (any TokenProvider) -> Bool

    init<T: TokenProvider & Hashable>(_ base: T) {
        self.base = base
        self._hash = base.hash(into:)
        self._equals = { other in
            guard let other = other as? T else { return false }
            return base == other
        }
    }

    func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }

    static func == (lhs: AnyTokenProvider, rhs: AnyTokenProvider) -> Bool {
        lhs._equals(rhs.base)
    }

    func asTokenProvider() -> any TokenProvider {
        base
    }
}
