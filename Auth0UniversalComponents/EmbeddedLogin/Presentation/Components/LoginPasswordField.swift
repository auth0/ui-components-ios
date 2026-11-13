import SwiftUI

/// The "Password" label, the field and the error under it. The text is hidden until the user chooses to show it, and is
/// hidden again when the app leaves the foreground or a request starts. Holds no rules: whoever hosts it decides
/// what's wrong.
struct LoginPasswordField: View {
    @Binding var password: String
    let error: String?
    /// A request is on its way: the field locks.
    let isEnabled: Bool
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var isRevealed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel("Password")
            LoginInputField(isInvalid: error != nil) {
                entry
                    .passwordInput()
                    .focused(isFocused)
                    .onSubmit(onSubmit)
                    .disabled(!isEnabled)
                    .accessibilityLabel("Password")
            } trailing: {
                Button { isRevealed.toggle() } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(theme.colors.text.regular)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
            // The other kind of field is a different view: put the cursor back where the user was typing.
            .onChangeCompat(of: isRevealed) { _ in isFocused.wrappedValue = true }
            // Not left readable in the app switcher's snapshot, or on screen for the next attempt.
            .onChangeCompat(of: scenePhase) { if $0 != .active { isRevealed = false } }
            .onChangeCompat(of: isEnabled) { if !$0 { isRevealed = false } }

            if let error {
                LoginInlineError(error)
                    .padding(.top, theme.spacing.xs)
            }
        }
    }

    @ViewBuilder
    private var entry: some View {
        if isRevealed {
            TextField("", text: $password)
        } else {
            SecureField("", text: $password)
        }
    }
}
