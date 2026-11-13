import SwiftUI

/// Email entry: the field and Continue. Checks the format before handing the address on. Continue is off while that
/// check's error shows, but not after a server error, so the same address can be tried again. The text is the host's.
struct LoginEmailForm: View {
    @Binding var email: String
    let isLoading: Bool
    /// The server's error (e.g. the code couldn't be sent). Hidden once the user edits.
    let serverError: String?
    /// The bottom of the screen (an email-only screen), or right under the field (the first of several ways).
    var pinsContinueToBottom = false
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var errors = LoginFieldErrors()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginEmailField(email: $email, error: errors.shown(server: serverError), isFocused: $isFocused,
                            onSubmit: submit)
            if pinsContinueToBottom { Spacer(minLength: theme.spacing.xl) }
            LoginPrimaryButton("Continue", isLoading: isLoading, isEnabled: !email.isEmpty && errors.validation == nil,
                               action: submit)
                .padding(.top, pinsContinueToBottom ? 0 : theme.spacing.md)
        }
        .onAppear { isFocused = true }
        .onChangeCompat(of: email) { _ in errors.userEdited() }
        .onChangeCompat(of: serverError) { if $0 != nil { errors.serverReported() } }
        .announcing(errors.shown(server: serverError))
    }

    private func submit() {
        // Return on the keyboard bypasses the button's guards.
        guard !isLoading, errors.validation == nil else { return }
        guard EmailValidator.isValid(email) else {
            errors.validation = "Please enter a valid email address."
            return
        }
        onContinue(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
