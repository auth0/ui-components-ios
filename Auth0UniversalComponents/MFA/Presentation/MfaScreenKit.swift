import SwiftUI

// The visual building blocks MFA screens share with the rest of the SDK, under neutral names. This is the one file in
// the Core's presentation that names where they live, so moving them later touches nothing else.

typealias MfaHeader = FactorScreenHeader
typealias MfaStyle = FactorScreenStyle
typealias MfaStatusLayout<Action: View> = StatusLayout<Action>
typealias MfaTextButton = FactorTextButton
typealias MfaResendButton = FactorCountdownResendButton
typealias MfaRowButtonStyle = FactorRowButtonStyle
typealias MfaSpinner = BrandSpinner
typealias MfaPrimaryButton = LoginPrimaryButton
/// The header of the code screens: a masked number's `*` drawn small and top-aligned.
typealias MfaCodeHeader = LoginScreenHeader
/// Label, digit boxes, error, Verify and actions, laid out exactly as on the sign-in's code screen.
typealias MfaCodeEntryForm<Actions: View> = CodeEntryForm<Actions>
/// The sign-in's "Resend Code" text, with the countdown passed in.
typealias MfaResendCodeButton = ResendCodeButton
/// A value as the server masked it, with each `*` drawn small and top-aligned.
typealias MfaMaskedText = MaskedText

extension View {
    /// Padding and background for an MFA screen.
    func mfaScreenChrome(theme: Auth0Theme, horizontalPadding: CGFloat? = nil,
                         topPadding: CGFloat? = nil) -> some View {
        embeddedScreenChrome(theme: theme, horizontalPadding: horizontalPadding, topPadding: topPadding)
    }
}
