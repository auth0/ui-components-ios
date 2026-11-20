import SwiftUI

// How the entry screen is put together, and how a brand changes it. The entry screen is the first one of Embedded Login
// and of sign-up: a logo, a title, the field with Continue, the way to the other flow ("Sign up" or "Log in"), and the
// other ways to continue. The SDK builds the pieces; a layout places them.

/// The pieces of an entry screen, built by the SDK and placed by an `EmbeddedEntryLayout`. A layout may leave a piece
/// out, move it or wrap it, but the field and Continue stay together in `form`.
public struct EmbeddedEntryParts {
    /// The logo: the theme's by default (`Auth0Theme.brand`), or what the app set with `embeddedEntryLogo(_:)`. `nil`
    /// when it is hidden.
    public let logo: AnyView?
    public let title: AnyView
    /// The field and Continue.
    public let form: AnyView
    /// "Don't have an account? Sign up" or "Already have an account? Log in", when there is one to offer.
    public let accountLink: AnyView?
    /// "OR" and a button for each other way, when the tenant offers more than one.
    public let alternatives: AnyView?
}

/// Where the pieces of the entry screen go. `.centered` is the default; a brand can write its own:
///
/// ```swift
/// EmbeddedEntryLayout { parts in
///     VStack(spacing: 24) {
///         parts.logo
///         parts.title
///         parts.form
///         parts.accountLink
///     }
/// }
/// ```
public struct EmbeddedEntryLayout {
    let make: (EmbeddedEntryParts) -> AnyView

    public init<Content: View>(@ViewBuilder _ make: @escaping (EmbeddedEntryParts) -> Content) {
        self.make = { AnyView(make($0)) }
    }

    /// The logo, the title, the field and the links as one block in the middle of the screen, as the designs have it.
    public static var centered: EmbeddedEntryLayout {
        EmbeddedEntryLayout { StackedEntry(parts: $0, isCentered: true) }
    }

    /// The same block, starting at the top of the screen.
    public static var top: EmbeddedEntryLayout { EmbeddedEntryLayout { StackedEntry(parts: $0, isCentered: false) } }
}

/// The words of the entry screen. A title or a prompt a brand doesn't set keeps its default.
public struct EmbeddedEntryMessages: Equatable, Sendable {
    /// The login's title when the tenant doesn't offer sign-up. `nil` keeps the way's own ("Enter your email to get
    /// started").
    public var loginTitle: String?
    /// The login's title when the tenant offers sign-up as well.
    public var loginOrSignUpTitle: String
    public var signUpTitle: String
    public var signUpPrompt: String
    public var signUpAction: String
    public var logInPrompt: String
    public var logInAction: String

    public init(loginTitle: String? = nil,
                loginOrSignUpTitle: String = "Log in or sign up",
                signUpTitle: String = "Create your account",
                signUpPrompt: String = "Don’t have an account?",
                signUpAction: String = "Sign up",
                logInPrompt: String = "Already have an account?",
                logInAction: String = "Log in") {
        self.loginTitle = loginTitle
        self.loginOrSignUpTitle = loginOrSignUpTitle
        self.signUpTitle = signUpTitle
        self.signUpPrompt = signUpPrompt
        self.signUpAction = signUpAction
        self.logInPrompt = logInPrompt
        self.logInAction = logInAction
    }
}

/// Which logo the entry screens show.
public enum EmbeddedEntryLogo {
    /// The theme's: `Auth0Theme.brand.logo`, Auth0's unless the app's theme replaces it. Set it once there and every
    /// screen that shows the logo follows.
    case theme
    /// A view of the app's own, for this screen only.
    case custom(AnyView)
    /// No logo.
    case hidden
}

/// Everything a brand can set on the entry screen. Every part is optional: the defaults are the SDK's own.
public struct EmbeddedEntryConfiguration {
    public var logo: EmbeddedEntryLogo
    public var layout: EmbeddedEntryLayout
    public var messages: EmbeddedEntryMessages
    /// The colour of "Sign up" and "Log in". `nil` uses the theme's `foreground.linkPrimary` (#9921FE).
    public var linkColor: Color?

    public init(logo: EmbeddedEntryLogo = .theme, layout: EmbeddedEntryLayout = .centered,
                messages: EmbeddedEntryMessages = EmbeddedEntryMessages(), linkColor: Color? = nil) {
        self.logo = logo
        self.layout = layout
        self.messages = messages
        self.linkColor = linkColor
    }
}

// MARK: - Environment

private struct EmbeddedEntryKey: EnvironmentKey {
    static var defaultValue: EmbeddedEntryConfiguration { EmbeddedEntryConfiguration() }
}

extension EnvironmentValues {
    var embeddedEntry: EmbeddedEntryConfiguration {
        get { self[EmbeddedEntryKey.self] }
        set { self[EmbeddedEntryKey.self] = newValue }
    }
}

public extension View {
    /// Sets how the entry screens of `EmbeddedLoginView` and `EmbeddedSignupView` look, below this view.
    func embeddedEntry(_ configuration: EmbeddedEntryConfiguration) -> some View {
        environment(\.embeddedEntry, configuration)
    }

    /// Sets the logo of the entry screens to a view of your own, leaving the rest of their configuration as it is. To
    /// change it everywhere, set `Auth0Theme.brand` instead.
    func embeddedEntryLogo<Logo: View>(@ViewBuilder _ logo: () -> Logo) -> some View {
        let logo = EmbeddedEntryLogo.custom(AnyView(logo()))
        return transformEnvironment(\.embeddedEntry) { $0.logo = logo }
    }

    /// Sets which logo the entry screens show: `.theme` (the default), `.hidden`, or `.custom`.
    func embeddedEntryLogo(_ logo: EmbeddedEntryLogo) -> some View {
        transformEnvironment(\.embeddedEntry) { $0.logo = logo }
    }

    /// Sets where the pieces of the entry screens go, leaving the rest of their configuration as it is.
    func embeddedEntryLayout(_ layout: EmbeddedEntryLayout) -> some View {
        transformEnvironment(\.embeddedEntry) { $0.layout = layout }
    }

    /// Sets the words of the entry screens, leaving the rest of their configuration as it is.
    func embeddedEntryMessages(_ messages: EmbeddedEntryMessages) -> some View {
        transformEnvironment(\.embeddedEntry) { $0.messages = messages }
    }
}

// MARK: - The default layouts

private struct StackedEntry: View {
    let parts: EmbeddedEntryParts
    let isCentered: Bool

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if isCentered { Spacer(minLength: theme.spacing.lg) }
            // The designs' gaps: 24 under the logo, 32 under the title, 16 above the link.
            if let logo = parts.logo {
                logo.padding(.bottom, theme.spacing.lg)
            }
            parts.title.padding(.bottom, theme.spacing.xl)
            parts.form
            if let accountLink = parts.accountLink {
                accountLink.padding(.top, theme.spacing.md)
            }
            if let alternatives = parts.alternatives {
                alternatives.padding(.top, theme.spacing.lg)
            }
            Spacer(minLength: theme.spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }
}
