import SwiftUI

/// One-time code entry.
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

    @Environment(\.auth0Theme) private var theme
    @State private var code = ""
    @State private var suppressError = false

    public init(title: String = "Enter the 6-digit code",
                subtitle: String? = nil,
                fieldLabel: String = "One-Time Passcode",
                digitCount: Int = 6,
                isLoading: Bool = false,
                errorMessage: String? = nil,
                isCodeExpired: Bool = false,
                onVerify: @escaping (String) -> Void,
                onEdit: (() -> Void)? = nil,
                onResend: (() -> Void)? = nil) {
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
    }

    private var activeError: String? { suppressError && !isCodeExpired ? nil : errorMessage }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title, subtitle: subtitle, isEditEnabled: !isLoading, onEdit: onEdit)

            CodeEntryForm(code: $code, digitCount: digitCount, fieldLabel: fieldLabel, isVerifying: isLoading,
                          error: activeError, canVerify: !isCodeExpired, onVerify: onVerify) {
                if let onResend {
                    LoginResendButton(isBusy: isLoading, isAvailableNow: isCodeExpired) {
                        // The expired code is no use once a new one is on its way.
                        if isCodeExpired { code = "" }
                        onResend()
                    }
                }
            }

            Spacer()
        }
        .embeddedScreenChrome(theme: theme)
        .onChangeCompat(of: code) { _ in suppressError = true }
        .onChangeCompat(of: errorMessage) { if $0 != nil { suppressError = false } }
    }
}

#Preview("Code") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {})
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
