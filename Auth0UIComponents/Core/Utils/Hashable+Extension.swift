import SwiftUI
import Combine
import Foundation
import Auth0

/// Represents a navigation route in Auth0 UI Components enrollment flows.
///
/// Routes define the possible destinations that users can navigate to during
/// authentication method enrollment, management, and verification.
enum Route: Hashable {
    /// Route to the passkey enrollment screen
    case enrollPasskeyScreen
    /// Route to the email/phone enrollment screen with a specific method type
    case emailPhoneEnrollmentScreen(type: AuthMethodType)
    /// Route to the TOTP/Push QR code display screen
    case totpPushQRScreen(type: AuthMethodType)
    /// Route to the recovery code enrollment screen
    case recoveryCodeScreen
    /// Route to the OTP verification screen with associated challenge data
    case otpScreen(type: AuthMethodType,
                   emailOrPhoneNumber: String? = nil,
                   totpEnrollmentChallege: TOTPEnrollmentChallenge? = nil,
                   phoneEnrollmentChallenge: PhoneEnrollmentChallenge? = nil,
                   emailEnrollmentChallenge: EmailEnrollmentChallenge? = nil)
    /// Route to the filtered authentication method selection screen
    case filteredAuthListScreen(type: AuthMethodType,
                                authMethods: [AuthenticationMethod])
}

/// Makes AuthMethodType conform to Hashable for use in routes.
extension AuthMethodType: Hashable {
}

/// Makes TOTPEnrollmentChallenge from Auth0 SDK conform to Hashable.
///
/// Compares challenges by their authenticationId and uses it for hashing.
extension TOTPEnrollmentChallenge: @retroactive Hashable {
    /// Compares two TOTP challenges by their authentication ID.
    public static func == (lhs: TOTPEnrollmentChallenge, rhs: TOTPEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    /// Hashes the challenge using its authentication ID.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

/// Makes PhoneEnrollmentChallenge from Auth0 SDK conform to Hashable.
///
/// Compares challenges by their authenticationId and uses it for hashing.
extension PhoneEnrollmentChallenge: @retroactive Hashable {
    /// Compares two phone challenges by their authentication ID.
    public static func == (lhs: PhoneEnrollmentChallenge, rhs: PhoneEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    /// Hashes the challenge using its authentication ID.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

/// Makes EmailEnrollmentChallenge from Auth0 SDK conform to Hashable.
///
/// Compares challenges by their authenticationId and uses it for hashing.
extension EmailEnrollmentChallenge: @retroactive Hashable {
    /// Compares two email challenges by their authentication ID.
    public static func == (lhs: EmailEnrollmentChallenge, rhs: EmailEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    /// Hashes the challenge using its authentication ID.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

/// Type-erased wrapper for TokenProvider conforming to Hashable.
///
/// This wrapper allows any TokenProvider that conforms to Hashable to be stored
/// and compared in collections that require Hashable conformance. It preserves
/// the original type's equality and hashing behavior.
struct AnyTokenProvider: Hashable {
    /// The underlying TokenProvider instance
    private let base: any TokenProvider
    /// Closure for hashing the wrapped provider
    private let _hash: (inout Hasher) -> Void
    /// Closure for comparing equality with another TokenProvider
    private let _equals: (any TokenProvider) -> Bool

    /// Initializes the wrapper with a hashable TokenProvider.
    ///
    /// - Parameter base: A TokenProvider that also conforms to Hashable
    init<T: TokenProvider & Hashable>(_ base: T) {
        self.base = base
        self._hash = base.hash(into:)
        self._equals = { other in
            guard let other = other as? T else { return false }
            return base == other
        }
    }

    /// Hashes the wrapped token provider.
    func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }

    /// Compares two type-erased token providers.
    static func == (lhs: AnyTokenProvider, rhs: AnyTokenProvider) -> Bool {
        lhs._equals(rhs.base)
    }

    /// Extracts and returns the underlying TokenProvider.
    func asTokenProvider() -> any TokenProvider {
        base
    }
}
