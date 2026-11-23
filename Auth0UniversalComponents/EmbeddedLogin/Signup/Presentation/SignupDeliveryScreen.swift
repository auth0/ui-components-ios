import SwiftUI

/// Asked once a number is accepted, when it takes both a text and a call: how does the user want the code? Continue
/// sends it that way.
struct SignupDeliveryScreen: View {
    /// The number as the server masked it.
    let sentTo: String
    let ways: [CodeDelivery]
    let isLoading: Bool
    /// The server's error (e.g. the code couldn't be sent), under the choices.
    let errorMessage: String?
    let onEdit: () -> Void
    let onContinue: (CodeDelivery) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var selected: CodeDelivery

    init(sentTo: String, ways: [CodeDelivery], isLoading: Bool = false, errorMessage: String? = nil,
         onEdit: @escaping () -> Void, onContinue: @escaping (CodeDelivery) -> Void) {
        self.sentTo = sentTo
        self.ways = ways
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onEdit = onEdit
        self.onContinue = onContinue
        _selected = State(initialValue: ways.first ?? .text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: "Choose how to get your code", subtitle: "We’ll send a code to \(sentTo)",
                              subtitleLineLimit: nil, isEditEnabled: !isLoading, onEdit: onEdit,
                              editColor: theme.colors.foreground.linkPrimary)

            LoginFieldLabel("How do you want to receive the code?")
            HStack(spacing: theme.spacing.md) {
                ForEach(ways, id: \.self) { way in
                    LoginChoiceButton(way.choiceTitle, isSelected: way == selected, isEnabled: !isLoading) {
                        selected = way
                    }
                }
            }
            if let errorMessage {
                LoginInlineError(errorMessage)
                    .padding(.top, theme.spacing.xs)
            }

            Spacer(minLength: theme.spacing.lg)
            LoginPrimaryButton("Continue", isLoading: isLoading) { onContinue(selected) }
        }
        .announcing(errorMessage)
        .embeddedScreenChrome(theme: theme, scrolls: true)
    }
}

private extension CodeDelivery {
    /// The choice's name on its button.
    var choiceTitle: String {
        switch self {
        case .email: return "Email"
        case .text: return "Text message"
        case .voice: return "Voice call"
        }
    }
}

#Preview("Choose how") {
    SignupDeliveryScreen(sentTo: "+1***-***-4567", ways: [.text, .voice], onEdit: {}, onContinue: { _ in })
}

#Preview("Choose how – send failed") {
    SignupDeliveryScreen(sentTo: "+1***-***-4567", ways: [.text, .voice],
                         errorMessage: SignupFailure.codeNotSent.message(for: .phone), onEdit: {},
                         onContinue: { _ in })
}
