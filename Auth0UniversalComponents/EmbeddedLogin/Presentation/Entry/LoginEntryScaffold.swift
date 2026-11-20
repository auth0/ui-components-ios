import SwiftUI

/// Which way to the other flow the entry screen offers.
enum LoginAccountLink: Equatable {
    /// On the login: "Don't have an account? Sign up".
    case signUp
    /// On sign-up, when it was opened from the login: "Already have an account? Log in".
    case logIn
}

/// Builds the pieces of an entry screen and hands them to the brand's layout, inside the screen's usual chrome. The
/// login's first screen and sign-up's both use it, so a brand changes both in one place.
struct LoginEntryScaffold: View {
    let title: String
    let form: AnyView
    var accountLink: LoginAccountLink?
    var isEnabled = true
    var onAccountLink: () -> Void = {}
    var alternatives: AnyView?

    @Environment(\.auth0Theme) private var theme
    @Environment(\.embeddedEntry) private var entry

    var body: some View {
        entry.layout.make(parts)
            .embeddedScreenChrome(theme: theme, scrolls: true)
    }

    private var parts: EmbeddedEntryParts {
        EmbeddedEntryParts(
            logo: logo,
            title: AnyView(titleView),
            form: form,
            accountLink: accountLink.map { link in
                AnyView(LoginAccountLinkRow(prompt: prompt(of: link), action: action(of: link),
                                            color: entry.linkColor, isEnabled: isEnabled, onTap: onAccountLink))
            },
            alternatives: alternatives)
    }

    private var logo: AnyView? {
        switch entry.logo {
        case .hidden: return nil
        case let .custom(view): return view
        case .theme: return AnyView(themeLogo)
        }
    }

    /// The theme's logo at the theme's height, in the text colour so that a template image reads in dark mode too.
    private var themeLogo: some View {
        theme.brand.logo
            .resizable()
            .scaledToFit()
            .frame(height: theme.sizes.logoHeight)
            .foregroundStyle(theme.colors.text.bold)
            .accessibilityLabel(theme.brand.logoLabel)
    }

    private var titleView: some View {
        Text(title)
            .auth0TextStyle(theme.typography.display)
            .foregroundStyle(theme.colors.text.bold)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func prompt(of link: LoginAccountLink) -> String {
        link == .signUp ? entry.messages.signUpPrompt : entry.messages.logInPrompt
    }

    private func action(of link: LoginAccountLink) -> String {
        link == .signUp ? entry.messages.signUpAction : entry.messages.logInAction
    }
}

/// "Don't have an account? Sign up": the prompt, then the action as a button. At the largest text sizes they stack.
struct LoginAccountLinkRow: View {
    let prompt: String
    let action: String
    let color: Color?
    let isEnabled: Bool
    let onTap: () -> Void

    @Environment(\.auth0Theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let tapPadding: CGFloat = 13

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: theme.spacing.xs))
        layout {
            Text(prompt)
                .auth0TextStyle(theme.typography.helper)
                .foregroundStyle(theme.colors.text.regular)
            Button(action: onTap) {
                Text(action)
                    .auth0TextStyle(theme.typography.helper)
                    .foregroundStyle(color ?? theme.colors.foreground.linkPrimary)
                    // 44 pt to tap, without the space: the padding that makes the target is taken back out.
                    .padding(.vertical, Self.tapPadding)
                    .padding(.horizontal, theme.spacing.xs)
                    .contentShape(Rectangle())
                    .padding(.vertical, -Self.tapPadding)
                    .padding(.horizontal, -theme.spacing.xs)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Entry – log in or sign up") {
    LoginEntryScaffold(title: "Log in or sign up", form: AnyView(Text("field and Continue")), accountLink: .signUp)
}
