import SwiftUI

// Input screens. Each is plug-and-play: plain values in, closures out, no coordinator.

/// Collects the email the code is sent to.
public struct LoginEmailScreen: View {
    let title: String
    let isLoading: Bool
    /// Server-side error (e.g. code couldn't be sent). Cleared from view once the user edits.
    let errorMessage: String?
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var email: String
    @State private var validationError: String?
    @State private var suppressServerError = false
    @FocusState private var isFocused: Bool

    public init(title: String = "Enter your email to get started",
                email: String = "",
                isLoading: Bool = false,
                errorMessage: String? = nil,
                onContinue: @escaping (String) -> Void) {
        self.title = title
        self._email = State(initialValue: email)
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
    }

    private var activeError: String? { validationError ?? (suppressServerError ? nil : errorMessage) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title)

            LoginFieldLabel("Email")
            LoginInputField(isInvalid: activeError != nil) {
                TextField("", text: $email)
                    .emailInput()
                    .focused($isFocused)
                    .onSubmit(submit)
            }

            if let activeError {
                LoginInlineError(activeError)
                    .padding(.top, theme.spacing.xs)
            }

            Spacer(minLength: theme.spacing.xl)

            LoginPrimaryButton("Continue", isLoading: isLoading, isEnabled: !email.isEmpty, action: submit)
        }
        .embeddedScreenChrome(theme: theme)
        .onAppear { isFocused = true }
        .onChange(of: email) { _ in
            validationError = nil
            suppressServerError = true
        }
        .onChange(of: errorMessage) { if $0 != nil { suppressServerError = false } }
    }

    private func submit() {
        // Return on the keyboard bypasses the button's loading guard.
        guard !isLoading else { return }
        guard EmailValidator.isValid(email) else {
            validationError = "Please enter a valid email address."
            return
        }
        onContinue(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

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

// MARK: - Previews

#Preview("Email") {
    LoginEmailScreen { _ in }
}

#Preview("Email – send failed") {
    LoginEmailScreen(email: "sarah.doe@atko.email", errorMessage: AuthFailure.codeNotSent.message) { _ in }
}

#Preview("Code") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {})
}

#Preview("Code – rejected") {
    LoginCodeScreen(subtitle: "From sarah.doe@atko.email", errorMessage: AuthFailure.invalidCode.message,
                    onVerify: { _ in }, onEdit: {}, onResend: {})
}
