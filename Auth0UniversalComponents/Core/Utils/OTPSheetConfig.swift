import Auth0
import SwiftUI

/// Configuration value type passed to the OTP sheet.
///
/// Carries everything OTPViewModel needs to verify a one-time passcode,
/// without requiring the Route enum or any navigation infrastructure.
struct OTPSheetConfig: Equatable {
    let type: AuthMethodType
    let emailOrPhoneNumber: String?
    let totpEnrollmentChallenge: TOTPEnrollmentChallenge?
    let phoneEnrollmentChallenge: PhoneEnrollmentChallenge?
    let emailEnrollmentChallenge: EmailEnrollmentChallenge?
}

#if os(iOS)
/// Applies a 24 pt corner radius to a sheet on iOS 16.4+; no-op on earlier versions.
public struct RoundedSheetModifier: ViewModifier {
    public func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCornerRadius(24)
        } else {
            content
        }
    }
}
#endif
