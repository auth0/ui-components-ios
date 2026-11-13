import SwiftUI

/// Collects the password for the username, email or number entered on the screen before, shown in a labelled row with
/// an Edit action. With a code also on offer, Continue sits under the field, then "OR" and a button for the code, as on
/// the first screen; on its own, Continue sits at the bottom of the screen. Whichever button was tapped shows the
/// progress, and the screen keeps its shape while the request is on its way. The content scrolls when the keyboard
/// leaves too little room.
struct LoginPasswordScreen: View {
    let title: String
    let username: String
    /// The label over the row, the one the field had on the screen before: "Email", "Phone number" or "Username".
    let identifierLabel: String
    let isLoading: Bool
    /// The server's rejection (e.g. a wrong password). Hidden once the user types again.
    let errorMessage: String?
    let onContinue: (String) -> Void
    let onEdit: (() -> Void)?
    /// `nil` hides the way to a code.
    let onSendCode: (() -> Void)?
    let sendCodeTitle: String
    let sendCodeIcon: Image?
    /// When another code may be asked for; the code button counts down until then.
    let sendCodeAvailableAt: Date?

    @Environment(\.auth0Theme) private var theme
    @State private var password = ""
    @State private var errors = LoginFieldErrors()
    /// The request in flight is the code's, not the password's: the code button shows the progress.
    @State private var isSendingCode = false
    @FocusState private var isFocused: Bool

    init(title: String = "Enter your password",
         username: String,
         identifierLabel: String = "Username",
         isLoading: Bool = false,
         errorMessage: String? = nil,
         onContinue: @escaping (String) -> Void,
         onEdit: (() -> Void)? = nil,
         onSendCode: (() -> Void)? = nil,
         sendCodeTitle: String = "Send me a code",
         sendCodeIcon: Image? = nil,
         sendCodeAvailableAt: Date? = nil) {
        self.title = title
        self.username = username
        self.identifierLabel = identifierLabel
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
        self.onEdit = onEdit
        self.onSendCode = onSendCode
        self.sendCodeTitle = sendCodeTitle
        self.sendCodeIcon = sendCodeIcon
        self.sendCodeAvailableAt = sendCodeAvailableAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title)
            LoginIdentifierRow(label: identifierLabel, value: username, isEditEnabled: !isLoading, onEdit: onEdit)
                .padding(.bottom, theme.spacing.lg)
            LoginPasswordField(password: $password, error: errors.shown(server: errorMessage), isEnabled: !isLoading,
                               isFocused: $isFocused, onSubmit: submit)

            if let onSendCode {
                continueButton
                    .padding(.top, theme.spacing.md)
                LoginMethodDivider()
                    .padding(.vertical, theme.spacing.md)
                LoginCodeAlternativeButton(title: sendCodeTitle, icon: sendCodeIcon, availableAt: sendCodeAvailableAt,
                                           isLoading: isLoading && isSendingCode, isEnabled: !isLoading) {
                    isSendingCode = true
                    onSendCode()
                }
            } else {
                Spacer(minLength: theme.spacing.xl)
                continueButton
            }
        }
        .embeddedScreenChrome(theme: theme, scrolls: true)
        .onAppear { isFocused = true }
        .onChangeCompat(of: password) { _ in errors.userEdited() }
        .onChangeCompat(of: errorMessage) { if $0 != nil { errors.serverReported() } }
        // A rejection leaves the field empty and ready for another try.
        .onChangeCompat(of: isLoading) {
            if !$0 {
                isSendingCode = false
                isFocused = true
            }
        }
        .announcing(errors.shown(server: errorMessage))
    }

    private var continueButton: some View {
        LoginPrimaryButton("Continue", isLoading: isLoading && !isSendingCode,
                           isEnabled: !password.isEmpty && !isLoading, action: submit)
    }

    private func submit() {
        // Return on the keyboard bypasses the button's guards.
        guard !isLoading, !password.isEmpty else { return }
        onContinue(password)
        // Emptied whatever the answer: a rejected password can't be sent again by a second tap, and none is left on
        // screen.
        password = ""
    }
}

#Preview("Password") {
    LoginPasswordScreen(username: "sarah.doe") { _ in }
}

#Preview("Password – wrong password") {
    LoginPasswordScreen(username: "sarah.doe",
                        errorMessage: AuthFailure.invalidPassword.message(for: .password)) { _ in }
}

#Preview("Password – or a code") {
    LoginPasswordScreen(username: "sarah.doe@atko.email", identifierLabel: LoginChannel.email.fieldLabel,
                        onContinue: { _ in }, onEdit: {}, onSendCode: {},
                        sendCodeTitle: LoginChannel.email.sendCodeTitle, sendCodeIcon: LoginChannel.email.continueIcon)
}

#Preview("Password – code just sent") {
    LoginPasswordScreen(username: "sarah.doe@atko.email", identifierLabel: LoginChannel.email.fieldLabel,
                        onContinue: { _ in }, onEdit: {}, onSendCode: {},
                        sendCodeTitle: LoginChannel.email.sendCodeTitle, sendCodeIcon: LoginChannel.email.continueIcon,
                        sendCodeAvailableAt: .now.addingTimeInterval(42))
}

#Preview("Password – or a text") {
    LoginPasswordScreen(username: "+1 423 353 0900", identifierLabel: LoginChannel.phone.fieldLabel,
                        onContinue: { _ in }, onEdit: {}, onSendCode: {},
                        sendCodeTitle: LoginChannel.phone.sendCodeTitle, sendCodeIcon: LoginChannel.phone.continueIcon)
}

#Preview("Password – signing in") {
    LoginPasswordScreen(username: "sarah.doe", isLoading: true) { _ in }
}
