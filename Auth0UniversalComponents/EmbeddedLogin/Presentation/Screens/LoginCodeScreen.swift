import SwiftUI

/// One-time code entry. With a password on offer too, "OR" and a button for it sit under Resend, as on the first
/// screen.
public struct LoginCodeScreen: View {
    let title: String
    let subtitle: String?
    let fieldLabel: String
    let digitCount: Int
    let isLoading: Bool
    /// Rejection to show under the boxes. Hidden once the user retypes, unless the code expired.
    let errorMessage: String?
    /// The code timed out: only a new one helps. Verify stays off, Resend is offered at once, and the error stays.
    let isCodeExpired: Bool
    let onVerify: (String) -> Void
    let onEdit: (() -> Void)?
    /// `nil` hides the resend row.
    let onResend: (() -> Void)?
    /// `nil` hides the way to a password.
    let onUsePassword: (() -> Void)?
    let usePasswordTitle: String
    let usePasswordIcon: Image?

    @Environment(\.auth0Theme) private var theme
    @State private var code = ""
    @State private var suppressError = false
    /// What the last tap asked for, so only that button answers the request in flight. Every tap sets it, so a tap the
    /// coordinator ignored can't leave the wrong button spinning for a later request.
    @State private var pending: Pending?

    private enum Pending { case verify, newCode, password }

    public init(title: String = "Enter the 6-digit code",
                subtitle: String? = nil,
                fieldLabel: String = "One-Time Passcode",
                digitCount: Int = 6,
                isLoading: Bool = false,
                errorMessage: String? = nil,
                isCodeExpired: Bool = false,
                onVerify: @escaping (String) -> Void,
                onEdit: (() -> Void)? = nil,
                onResend: (() -> Void)? = nil,
                onUsePassword: (() -> Void)? = nil,
                usePasswordTitle: String = "Continue with a password",
                usePasswordIcon: Image? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.fieldLabel = fieldLabel
        self.digitCount = digitCount
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.isCodeExpired = isCodeExpired
        self.onVerify = onVerify
        self.onEdit = onEdit
        self.onResend = onResend
        self.onUsePassword = onUsePassword
        self.usePasswordTitle = usePasswordTitle
        self.usePasswordIcon = usePasswordIcon
    }

    private var activeError: String? { suppressError && !isCodeExpired ? nil : errorMessage }

    private func verify(_ code: String) {
        pending = .verify
        onVerify(code)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title, subtitle: subtitle, isEditEnabled: !isLoading, onEdit: onEdit)

            CodeEntryForm(code: $code, digitCount: digitCount, fieldLabel: fieldLabel,
                          isVerifying: isLoading && (pending == nil || pending == .verify), isLocked: isLoading,
                          error: activeError, canVerify: !isCodeExpired && !isLoading, onVerify: verify) {
                VStack(spacing: theme.spacing.md) {
                    if let onResend {
                        LoginResendButton(isBusy: isLoading, isAvailableNow: isCodeExpired) {
                            // The expired code is no use once a new one is on its way.
                            if isCodeExpired { code = "" }
                            pending = .newCode
                            onResend()
                        }
                    }
                    if let onUsePassword {
                        LoginMethodDivider()
                        LoginSecondaryButton(usePasswordTitle, icon: usePasswordIcon,
                                             isLoading: isLoading && pending == .password, isEnabled: !isLoading) {
                            pending = .password
                            onUsePassword()
                        }
                    }
                }
            }

            Spacer()
        }
        .embeddedScreenChrome(theme: theme, scrolls: true)
        .onChangeCompat(of: code) { _ in suppressError = true }
        .onChangeCompat(of: errorMessage) { if $0 != nil { suppressError = false } }
        .onChangeCompat(of: isLoading) { if !$0 { pending = nil } }
    }
}

#Preview("Code") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {})
}

#Preview("Code – or a password") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {},
                    onUsePassword: {}, usePasswordIcon: LoginChannel.password.continueIcon)
}

#Preview("Code – rejected") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", errorMessage: AuthFailure.invalidCode.message(for: .email),
                    onVerify: { _ in }, onEdit: {}, onResend: {})
}

#Preview("Phone code – verifying") {
    LoginCodeScreen(subtitle: "From (4**)***-*900", isLoading: true, onVerify: { _ in }, onEdit: {}, onResend: {})
}

#Preview("Phone code – expired") {
    LoginCodeScreen(subtitle: "From (4**)***-*900", errorMessage: AuthFailure.codeExpired.message(for: .phone),
                    isCodeExpired: true, onVerify: { _ in }, onEdit: {}, onResend: {})
}
