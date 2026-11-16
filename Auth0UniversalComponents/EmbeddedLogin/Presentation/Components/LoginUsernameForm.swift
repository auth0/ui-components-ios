import SwiftUI

/// Username entry: the field and Continue. A username has no format to check, so Continue is on once there is
/// something typed. The server's error hides once the user edits. The text is the host's.
struct LoginUsernameForm: View {
    @Binding var username: String
    let isLoading: Bool
    /// The server's error (e.g. no password step for this username). Hidden once the user edits.
    let serverError: String?
    /// The bottom of the screen (a username-only screen), or right under the field (the first of several ways).
    var pinsContinueToBottom = false
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var errors = LoginFieldErrors()
    @FocusState private var isFocused: Bool

    private var trimmed: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginUsernameField(username: $username, error: errors.shown(server: serverError), isFocused: $isFocused,
                               onSubmit: submit)
            if pinsContinueToBottom { Spacer(minLength: theme.spacing.xl) }
            LoginPrimaryButton("Continue", isLoading: isLoading, isEnabled: !trimmed.isEmpty, action: submit)
                .padding(.top, pinsContinueToBottom ? 0 : theme.spacing.md)
        }
        .onAppear { isFocused = true }
        .onChangeCompat(of: username) { _ in errors.userEdited() }
        .onChangeCompat(of: serverError) { if $0 != nil { errors.serverReported() } }
        .announcing(errors.shown(server: serverError))
    }

    private func submit() {
        // Return on the keyboard bypasses the button's guards.
        guard !isLoading, !trimmed.isEmpty else { return }
        onContinue(trimmed)
    }
}
