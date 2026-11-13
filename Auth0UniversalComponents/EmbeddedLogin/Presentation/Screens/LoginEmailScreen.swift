import SwiftUI

/// Collects the email the code is sent to. Continue sits at the bottom of the screen.
public struct LoginEmailScreen: View {
    let title: String
    let isLoading: Bool
    /// Server-side error (e.g. code couldn't be sent). Cleared from view once the user edits.
    let errorMessage: String?
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var email: String

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

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title)
            LoginEmailForm(email: $email, isLoading: isLoading, serverError: errorMessage, pinsContinueToBottom: true,
                           onContinue: onContinue)
        }
        .embeddedScreenChrome(theme: theme, scrolls: true)
    }
}

#Preview("Email") {
    LoginEmailScreen { _ in }
}

#Preview("Email – send failed") {
    LoginEmailScreen(email: "sarah.doe@atko.email", errorMessage: AuthFailure.codeNotSent.message(for: .email)) { _ in }
}
