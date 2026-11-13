import SwiftUI

/// The "Email" label, the field and the error under it. Holds no rules: whoever hosts it decides what's wrong.
struct LoginEmailField: View {
    @Binding var email: String
    let error: String?
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel(LoginChannel.email.fieldLabel)
            LoginInputField(isInvalid: error != nil) {
                TextField("", text: $email)
                    .emailInput()
                    .focused(isFocused)
                    .onSubmit(onSubmit)
                    .accessibilityLabel(LoginChannel.email.fieldLabel)
            }

            if let error {
                LoginInlineError(error)
                    .padding(.top, theme.spacing.xs)
            }
        }
    }
}
