import Foundation

enum RecoveryCodeVerification: Equatable {
    /// Accepted. The code is used up: `newCode` replaces it, and the user must save it.
    case rotated(newCode: String)
    /// Not the user's code; they can try again.
    case rejected
}

enum RecoveryCodeConfirmation: Equatable {
    /// Done. The transport has already staged the credentials.
    case verified
    /// Done, and the policy asks for another factor.
    case anotherFactor([MfaFactorOffer])
}

/// What the recovery code factor needs from a server: check the code the user typed, then confirm that they saved the
/// new one the server issued in its place. Both calls throw `MfaError`.
///
/// A request may have to wait for its turn behind another one. `isWanted` is asked again when it comes: when it says
/// no, nothing is sent and the call throws `CancellationError`. Here that matters most: a check uses the code up, so it
/// must never go out after the user left and can't see the new one.
@MainActor
protocol RecoveryCodeTransport {
    func verify(code: String, while isWanted: () -> Bool) async throws -> RecoveryCodeVerification
    func confirm(while isWanted: () -> Bool) async throws -> RecoveryCodeConfirmation
}
