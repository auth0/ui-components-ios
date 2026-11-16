import SwiftUI

/// The "Username" label, the field and the error under it. Holds no rules: whoever hosts it decides what's wrong.
struct LoginUsernameField: View {
    @Binding var username: String
    let error: String?
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel(LoginChannel.password.fieldLabel)
            LoginInputField(isInvalid: error != nil) {
                TextField("", text: $username)
                    .usernameInput()
                    .focused(isFocused)
                    .onSubmit(onSubmit)
                    .accessibilityLabel(LoginChannel.password.fieldLabel)
            }

            if let error {
                LoginInlineError(error)
                    .padding(.top, theme.spacing.xs)
            }
        }
    }
}
