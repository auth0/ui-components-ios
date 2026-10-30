import SwiftUI

// The visual building blocks MFA screens share with the rest of the SDK, under neutral names. This is the one file in
// the Core's presentation that names where they live, so moving them later touches nothing else.

typealias MfaHeader = FactorScreenHeader
typealias MfaStyle = FactorScreenStyle
typealias MfaStatusLayout<Action: View> = StatusLayout<Action>
typealias MfaTextButton = FactorTextButton
typealias MfaResendButton = FactorResendButton
typealias MfaRowButtonStyle = FactorRowButtonStyle
typealias MfaSpinner = BrandSpinner
typealias MfaPrimaryButton = LoginPrimaryButton

extension View {
    /// Padding and background for an MFA screen.
    func mfaScreenChrome(theme: Auth0Theme, horizontalPadding: CGFloat? = nil,
                         topPadding: CGFloat? = nil) -> some View {
        embeddedScreenChrome(theme: theme, horizontalPadding: horizontalPadding, topPadding: topPadding)
    }
}
