import SwiftUI

/// Collects the username whose password is asked for next. Continue sits at the bottom of the screen.
struct LoginUsernameScreen: View {
    let title: String
    let isLoading: Bool
    /// Server-side error (e.g. no password step for this username). Cleared from view once the user edits.
    let errorMessage: String?
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var username: String

    init(title: String = "Enter your username to get started",
         username: String = "",
         isLoading: Bool = false,
         errorMessage: String? = nil,
         onContinue: @escaping (String) -> Void) {
        self.title = title
        self._username = State(initialValue: username)
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title)
            LoginUsernameForm(username: $username, isLoading: isLoading, serverError: errorMessage,
                              pinsContinueToBottom: true, onContinue: onContinue)
        }
        .embeddedScreenChrome(theme: theme)
    }
}

#Preview("Username") {
    LoginUsernameScreen { _ in }
}

#Preview("Username – no password step") {
    LoginUsernameScreen(username: "sarah.doe",
                        errorMessage: AuthFailure.invalidPassword.message(for: .password)) { _ in }
}
