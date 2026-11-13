import SwiftUI

/// The body of every one-time-code screen, under its header: the "One-Time Passcode" label, the digit boxes, an error
/// under them, Verify, and below it the screen's own actions (resend, "Verify another way"). Both the sign-in's code
/// screen and the SMS factor's use it, so their spacing and alignment can't drift apart.
struct CodeEntryForm<Actions: View>: View {
    @Binding var code: String
    let digitCount: Int
    let fieldLabel: String
    let verifyTitle: String
    /// A code is being checked: Verify shows progress and the boxes lock.
    let isVerifying: Bool
    /// Some other request is on its way (a new code, a password): the boxes lock, and Verify shows nothing.
    let isLocked: Bool
    /// Shown under the boxes, which turn red while it shows.
    let error: String?
    /// On top of a complete code, the screen may hold Verify back (e.g. an expired code).
    let canVerify: Bool
    let onVerify: (String) -> Void
    let actions: () -> Actions

    @Environment(\.auth0Theme) private var theme

    init(code: Binding<String>, digitCount: Int = 6, fieldLabel: String = "One-Time Passcode",
         verifyTitle: String = "Verify", isVerifying: Bool, isLocked: Bool = false, error: String?,
         canVerify: Bool = true,
         onVerify: @escaping (String) -> Void, @ViewBuilder actions: @escaping () -> Actions) {
        self._code = code
        self.digitCount = digitCount
        self.fieldLabel = fieldLabel
        self.verifyTitle = verifyTitle
        self.isVerifying = isVerifying
        self.isLocked = isLocked
        self.error = error
        self.canVerify = canVerify
        self.onVerify = onVerify
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel(fieldLabel)
            LoginCodeField(code: $code, digitCount: digitCount, isError: error != nil,
                           isEnabled: !isVerifying && !isLocked)

            if let error {
                LoginInlineError(error)
                    .padding(.top, theme.spacing.xs)
            }

            LoginPrimaryButton(verifyTitle, isLoading: isVerifying, isEnabled: isComplete && canVerify, action: verify)
                .padding(.top, theme.spacing.lg)

            actions()
                .padding(.top, theme.spacing.lg)
        }
    }

    private var isComplete: Bool { code.count == digitCount }

    private func verify() {
        guard !isVerifying, isComplete, canVerify else { return }
        onVerify(code)
    }
}
