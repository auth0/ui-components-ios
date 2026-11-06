import SwiftUI

/// The first screen when the tenant offers more than one way to sign in: the first way's form, with Continue under it,
/// then "OR" and a button for each other way. Choosing one opens that way's own screen.
struct LoginIdentifierScreen: View {
    let channel: LoginChannel
    let alternatives: [LoginChannel]
    let isLoading: Bool
    /// The server's error (e.g. the code couldn't be sent). Hidden once the user edits.
    let errorMessage: String?
    let onContinue: (LoginIdentifier) -> Void
    let onChoose: (LoginChannel) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var email: String
    @State private var number: String
    @State private var country: Country?

    /// - Parameter prefill: What the user last submitted on this screen, when they come back to it.
    init(channel: LoginChannel, alternatives: [LoginChannel], prefill: LoginIdentifier? = nil, isLoading: Bool = false,
         errorMessage: String? = nil, onContinue: @escaping (LoginIdentifier) -> Void,
         onChoose: @escaping (LoginChannel) -> Void) {
        self.channel = channel
        self.alternatives = alternatives
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
        self.onChoose = onChoose
        _email = State(initialValue: prefill?.channel == .email ? prefill?.value ?? "" : "")
        // Set before the first render, so the phone form doesn't take it for an edit and hide `errorMessage`.
        let entry = LoginPhoneForm.startingEntry(for: prefill?.channel == .phone ? prefill?.value ?? "" : "")
        _country = State(initialValue: channel == .phone ? entry.country : nil)
        _number = State(initialValue: channel == .phone ? entry.number : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: channel.title)
            form

            if !alternatives.isEmpty {
                LoginMethodDivider()
                    .padding(.vertical, theme.spacing.md)
                VStack(spacing: theme.spacing.sm) {
                    ForEach(alternatives, id: \.self) { alternative in
                        LoginSecondaryButton(alternative.continueTitle, icon: alternative.continueIcon,
                                             isEnabled: !isLoading) { onChoose(alternative) }
                    }
                }
            }
        }
        .embeddedScreenChrome(theme: theme)
    }

    @ViewBuilder
    private var form: some View {
        switch channel {
        case .email:
            LoginEmailForm(email: $email, isLoading: isLoading, serverError: errorMessage) {
                onContinue(.email($0))
            }
        case .phone:
            LoginPhoneForm(country: $country, number: $number, isLoading: isLoading, serverError: errorMessage) {
                onContinue(.phone($0))
            }
        }
    }
}

// MARK: - Per-channel words

extension LoginChannel {
    /// The screen's title when this way is asked for.
    var title: String {
        switch self {
        case .email: return "Enter your email to get started"
        case .phone: return "Enter your phone number to get started"
        }
    }

    /// The button that opens this way's screen.
    var continueTitle: String {
        switch self {
        case .email: return "Continue with Email"
        case .phone: return "Continue with Phone"
        }
    }

    /// That button's icon, in the button's text color. The button fits it to its icon size.
    var continueIcon: Image? {
        switch self {
        case .email: return Image("email", bundle: ResourceBundle.default).renderingMode(.template)
        case .phone: return Image("phone", bundle: ResourceBundle.default).renderingMode(.template)
        }
    }
}

#Preview("Email first, phone offered") {
    LoginIdentifierScreen(channel: .email, alternatives: [.phone], onContinue: { _ in }, onChoose: { _ in })
}

#Preview("Email first – send failed") {
    LoginIdentifierScreen(channel: .email, alternatives: [.phone], prefill: .email("sarah.doe@atko.email"),
                          errorMessage: AuthFailure.codeNotSent.message(for: .email),
                          onContinue: { _ in }, onChoose: { _ in })
}

#Preview("Phone first, email offered") {
    LoginIdentifierScreen(channel: .phone, alternatives: [.email], onContinue: { _ in }, onChoose: { _ in })
}
