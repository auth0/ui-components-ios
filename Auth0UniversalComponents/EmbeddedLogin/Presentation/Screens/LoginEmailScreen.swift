import SwiftUI

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
        .onChangeCompat(of: email) { _ in
            validationError = nil
            suppressServerError = true
        }
        .onChangeCompat(of: errorMessage) { if $0 != nil { suppressServerError = false } }
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

#Preview("Email") {
    LoginEmailScreen { _ in }
}

#Preview("Email – send failed") {
    LoginEmailScreen(email: "sarah.doe@atko.email", errorMessage: AuthFailure.codeNotSent.message) { _ in }
}
