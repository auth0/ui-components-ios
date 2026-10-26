import SwiftUI

/// One-time code entry.
public struct LoginCodeScreen: View {
    let title: String
    let subtitle: String?
    let fieldLabel: String
    let digitCount: Int
    let isLoading: Bool
    /// Rejection to show under the boxes. Hidden once the user retypes.
    let errorMessage: String?
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
                onVerify: @escaping (String) -> Void,
                onEdit: (() -> Void)? = nil,
                onResend: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.fieldLabel = fieldLabel
        self.digitCount = digitCount
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onVerify = onVerify
        self.onEdit = onEdit
        self.onResend = onResend
    }

    private var activeError: String? { suppressError ? nil : errorMessage }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title, subtitle: subtitle, isEditEnabled: !isLoading, onEdit: onEdit)

            LoginFieldLabel(fieldLabel)
            LoginCodeField(code: $code, digitCount: digitCount, isError: activeError != nil)

            if let activeError {
                LoginInlineError(activeError)
                    .padding(.top, theme.spacing.xs)
            }

            LoginPrimaryButton("Verify", isLoading: isLoading, isEnabled: code.count == digitCount, action: verify)
            .padding(.top, theme.spacing.lg)

            if let onResend {
                LoginResendButton(isBusy: isLoading, onResend: onResend)
                    .padding(.top, theme.spacing.lg)
            }

            Spacer()
        }
        .embeddedScreenChrome(theme: theme)
        .onChange(of: code) { _ in suppressError = true }
        .onChange(of: errorMessage) { if $0 != nil { suppressError = false } }
    }

    private func verify() {
        guard !isLoading, code.count == digitCount else { return }
        onVerify(code)
    }
}

#Preview("Code") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {})
}

#Preview("Code – rejected") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", errorMessage: AuthFailure.invalidCode.message,
                    onVerify: { _ in }, onEdit: {}, onResend: {})
}
