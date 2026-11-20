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
    /// Replaces the title: sign-up's, say. `nil` is the login's own.
    let title: String?
    /// The way to the other flow, under Continue. `nil` offers none.
    let accountLink: LoginAccountLink?
    let onAccountLink: () -> Void

    @Environment(\.auth0Theme) private var theme
    @Environment(\.embeddedEntry) private var entryConfiguration
    @State private var email: String
    @State private var number: String
    @State private var country: Country?
    @State private var username: String

    /// - Parameter prefill: What the user last submitted on this screen, when they come back to it.
    init(channel: LoginChannel, alternatives: [LoginChannel], prefill: LoginIdentifier? = nil, isLoading: Bool = false,
         errorMessage: String? = nil, title: String? = nil, accountLink: LoginAccountLink? = nil,
         onAccountLink: @escaping () -> Void = {}, onContinue: @escaping (LoginIdentifier) -> Void,
         onChoose: @escaping (LoginChannel) -> Void = { _ in }) {
        self.channel = channel
        self.alternatives = alternatives
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
        self.onChoose = onChoose
        self.title = title
        self.accountLink = accountLink
        self.onAccountLink = onAccountLink
        _email = State(initialValue: prefill?.channel == .email ? prefill?.value ?? "" : "")
        // Set before the first render, so the phone form doesn't take it for an edit and hide `errorMessage`.
        let entry = LoginPhoneForm.startingEntry(for: prefill?.channel == .phone ? prefill?.value ?? "" : "")
        _country = State(initialValue: channel == .phone ? entry.country : nil)
        _number = State(initialValue: channel == .phone ? entry.number : "")
        _username = State(initialValue: prefill?.channel == .password ? prefill?.value ?? "" : "")
    }

    var body: some View {
        LoginEntryScaffold(title: resolvedTitle, form: AnyView(form), accountLink: accountLink,
                           isEnabled: !isLoading, onAccountLink: onAccountLink,
                           alternatives: alternatives.isEmpty ? nil : AnyView(alternativeButtons))
    }

    /// Sign-up's own title when given; otherwise the login's: "Log in or sign up" when sign-up is offered, else the
    /// brand's, else the way's own.
    private var resolvedTitle: String {
        if let title { return title }
        if accountLink == .signUp { return entryConfiguration.messages.loginOrSignUpTitle }
        return entryConfiguration.messages.loginTitle ?? channel.title
    }

    private var alternativeButtons: some View {
        VStack(spacing: 0) {
            LoginMethodDivider()
                .padding(.bottom, theme.spacing.md)
            VStack(spacing: theme.spacing.sm) {
                ForEach(alternatives, id: \.self) { alternative in
                    LoginSecondaryButton(alternative.continueTitle, icon: alternative.continueIcon,
                                         isEnabled: !isLoading) { onChoose(alternative) }
                }
            }
        }
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
        case .password:
            LoginUsernameForm(username: $username, isLoading: isLoading, serverError: errorMessage) {
                onContinue(.username($0))
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
        case .password: return "Enter your username to get started"
        }
    }

    /// The button that opens this way's screen.
    var continueTitle: String {
        switch self {
        case .email: return "Continue with Email"
        case .phone: return "Continue with Phone"
        case .password: return "Continue with Password"
        }
    }

    /// The label over this way's field, and over the row that shows what was typed in it on the screens after.
    var fieldLabel: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone number"
        case .password: return "Username"
        }
    }

    /// The password screen's way to a code, for an email or number the server offers both for. Its icon is
    /// `continueIcon`: the envelope or the phone.
    var sendCodeTitle: String {
        switch self {
        case .email: return "Email me a code"
        case .phone: return "Text me a code"
        case .password: return "Send me a code"
        }
    }

    /// The asset behind `continueIcon`. A name that matches no asset draws nothing, so a test checks each exists.
    var iconAssetName: String {
        switch self {
        case .email: return "email"
        case .phone: return "phone"
        case .password: return "ic_uds_password"
        }
    }

    /// That button's icon, in the button's text color. The button fits it to its icon size.
    var continueIcon: Image {
        Image(iconAssetName, bundle: ResourceBundle.default).renderingMode(.template)
    }
}

#Preview("Email only, sign-up offered") {
    LoginIdentifierScreen(channel: .email, alternatives: [], accountLink: .signUp, onContinue: { _ in })
}

#Preview("Sign-up entry, opened from the login") {
    LoginIdentifierScreen(channel: .email, alternatives: [], title: "Create your account", accountLink: .logIn,
                          onContinue: { _ in })
}

#Preview("Email first, phone offered") {
    LoginIdentifierScreen(channel: .email, alternatives: [.phone], onContinue: { _ in }, onChoose: { _ in })
}

#Preview("Email first – send failed") {
    LoginIdentifierScreen(channel: .email, alternatives: [.phone], prefill: .email("sarah.doe@atko.email"),
                          errorMessage: AuthFailure.codeNotSent.message(for: .email),
                          onContinue: { _ in }, onChoose: { _ in })
}

#Preview("Email first, password offered") {
    LoginIdentifierScreen(channel: .email, alternatives: [.password], onContinue: { _ in }, onChoose: { _ in })
}

#Preview("Password first, email offered") {
    LoginIdentifierScreen(channel: .password, alternatives: [.email], onContinue: { _ in }, onChoose: { _ in })
}

#Preview("Phone first, email offered") {
    LoginIdentifierScreen(channel: .phone, alternatives: [.email], onContinue: { _ in }, onChoose: { _ in })
}
