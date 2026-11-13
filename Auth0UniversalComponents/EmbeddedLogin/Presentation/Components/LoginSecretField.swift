import SwiftUI

/// The label, a field for a secret the user types or pastes (hidden, with an eye to show it) and the error under it.
/// Holds no rules: whoever hosts it decides what's wrong.
struct LoginSecretField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    let isEnabled: Bool
    let onSubmit: () -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel(label)
            LoginInputField(isInvalid: error != nil, content: {
                field
                    .secretInput()
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .disabled(!isEnabled)
                    .accessibilityLabel(label)
            }, trailing: {
                Button {
                    isRevealed.toggle()
                    isFocused = true
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityLabel(isRevealed ? "Hide \(label)" : "Show \(label)")
            })

            if let error {
                LoginInlineError(error)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .onAppear { isFocused = true }
    }

    @ViewBuilder
    private var field: some View {
        if isRevealed {
            TextField(placeholder, text: $text)
        } else {
            SecureField(placeholder, text: $text)
        }
    }
}

#Preview("Hidden") {
    LoginSecretField(label: "Recovery Code", placeholder: "Your recovery code", text: .constant("N47HCYSDHRKW"),
                     error: nil, isEnabled: true, onSubmit: {})
        .padding()
}

#Preview("Error") {
    LoginSecretField(label: "Recovery Code", placeholder: "Your recovery code", text: .constant(""),
                     error: "Invalid recovery code.", isEnabled: true, onSubmit: {})
        .padding()
}
