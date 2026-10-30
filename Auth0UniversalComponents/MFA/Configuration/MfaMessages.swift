import Foundation

private func text(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: defaultValue, bundle: ResourceBundle.default)
}

/// A title with a line of explanation.
public struct MfaHeaderMessage: Sendable {
    /// The first line of text.
    public var title: String
    /// The explanation under the title.
    public var description: String

    /// Creates a title with an explanation.
    ///
    /// - Parameters:
    ///   - title: The first line of text.
    ///   - description: The explanation under the title.
    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
}

// swiftlint:disable nesting cyclomatic_complexity

/// A factor's copy. A factor defines one of these and exposes it as a computed property on `MfaMessages`, so the
/// Core's copy tree never has to know the factor exists.
public protocol MfaFactorMessages: Sendable {
    /// Unique per factor.
    static var key: String { get }
    /// The words used until the app changes them.
    static var defaults: Self { get }
}

/// The copy for every MFA screen, as a typed tree. Override any leaf; the rest keeps its default.
///
/// ```swift
/// let messages = MfaMessages.default.with {
///     $0.authenticatorList.headers.challengeAdditional.title = "One more step"
///     $0.pushChallenge.description = { device in "Approve the request on \(device)." }
/// }
/// ```
///
/// The Core owns the list headers, the loading label and the errors. Each factor adds its own branch (for example
/// `pushChallenge`) with an extension, so a new factor needs no change here. Strings that depend on a value are
/// functions, not templates. The tree is the same on Android.
public struct MfaMessages: Sendable {
    /// The headings of the factor list.
    public var authenticatorList = AuthenticatorList()
    /// The words shown while the flow is working.
    public var loading = Loading()
    /// The words for every way a flow can end badly.
    public var errors = Errors()
    private var factorMessages: [String: any Sendable] = [:]

    /// Creates the default words.
    public init() {}

    /// Resolved when asked for, so a language change since the last flow is picked up.
    public static var `default`: MfaMessages { MfaMessages() }

    /// A copy with `edit` applied.
    public func with(_ edit: (inout MfaMessages) -> Void) -> MfaMessages {
        var copy = self
        edit(&copy)
        return copy
    }

    /// A factor's copy, or its defaults until it is changed.
    public subscript<Messages: MfaFactorMessages>(_ type: Messages.Type) -> Messages {
        get { (factorMessages[Messages.key] as? Messages) ?? Messages.defaults }
        set { factorMessages[Messages.key] = newValue }
    }
}

// MARK: - Factor list

extension MfaMessages {
    /// The words of the factor list.
    public struct AuthenticatorList: Sendable {
        /// The two headings the factor list can have.
        public struct Headers: Sendable {
            /// Round one.
            public var challenge = MfaHeaderMessage(
                title: text("mfa.authenticatorList.headers.challenge.title", "Verify it's you"),
                description: text("mfa.authenticatorList.headers.challenge.description", "Choose how to verify."))
            /// After a successful factor, when the policy asks for another.
            public var challengeAdditional = MfaHeaderMessage(
                title: text("mfa.authenticatorList.headers.challengeAdditional.title", "One more step"),
                description: text("mfa.authenticatorList.headers.challengeAdditional.description",
                                  "Your account needs one more check."))
        }

        /// The factor list's headings.
        public var headers = Headers()
    }
}

// MARK: - Loading and errors

extension MfaMessages {
    /// The loading step has no screen of its own to brand; this is what VoiceOver reads.
    public struct Loading: Sendable {
        /// What VoiceOver reads while the flow is loading.
        public var accessibilityLabel = text("mfa.loading.accessibilityLabel", "Loading")
    }

    /// The words for each way a flow can end badly, one entry per ``MfaError``.
    public struct Errors: Sendable {
        /// The user cancelled. No screen shows this; it is here so you can word your own.
        public var cancelled = MfaHeaderMessage(
            title: text("mfa.errors.cancelled.title", "Verification cancelled."),
            description: text("mfa.errors.cancelled.description", "You cancelled verification."))
        /// The request expired before it was answered.
        public var tokenExpired = MfaHeaderMessage(
            title: text("mfa.errors.tokenExpired.title", "Request expired."),
            description: text("mfa.errors.tokenExpired.description",
                              "The request wasn't approved in time. Sign in again to send a new one."))
        /// The sign-in session ended or was already used.
        public var tokenInvalid = MfaHeaderMessage(
            title: text("mfa.errors.tokenInvalid.title", "Sign-in session ended."),
            description: text("mfa.errors.tokenInvalid.description",
                              "Your sign-in session ended. Please sign in again."))
        /// The server asked for more steps than the flow allows.
        public var maxChallengesExceeded = MfaHeaderMessage(
            title: text("mfa.errors.maxChallengesExceeded.title", "Too many verification steps."),
            description: text("mfa.errors.maxChallengesExceeded.description",
                              "We couldn't finish verifying you. Please sign in again."))
        /// The user denied the request on their device.
        public var rejected = MfaHeaderMessage(
            title: text("mfa.errors.rejected.title", "Sign-in request denied."),
            description: text("mfa.errors.rejected.description", """
                The request was denied. \
                If you didn't try to sign in, change your password.
                """))
        /// The server stopped the flow after too many wrong attempts.
        public var tooManyAttempts = MfaHeaderMessage(
            title: text("mfa.errors.tooManyAttempts.title", "Too many attempts."),
            description: text("mfa.errors.tooManyAttempts.description", "Please try again later."))
        /// None of the user's factors can be used here. The MFA screens don't show this: Embedded Login shows its own
        /// "not available" screen, or the app routes the user from `onMfaError`. It is here so you can word your own.
        public var noEligibleFactors = MfaHeaderMessage(
            title: text("mfa.errors.noEligibleFactors.title", "Verification method not available."),
            description: text("mfa.errors.noEligibleFactors.description", """
                Your account doesn't have a verification method this app can use. \
                Contact your administrator for help.
                """))
        /// The request never reached the server.
        public var network = MfaHeaderMessage(
            title: text("mfa.errors.network.title", "No connection."),
            description: text("mfa.errors.network.description", "Check your connection and try again."))
        /// The user was verified, but the sign-in could not be saved on this device.
        public var credentialsNotSaved = MfaHeaderMessage(
            title: text("mfa.errors.credentialsNotSaved.title", "Sign in couldn't be completed."),
            description: text("mfa.errors.credentialsNotSaved.description",
                              "We couldn't save your sign-in on this device. Please try again."))
        /// Anything else. A message the error carries is shown in place of the description.
        public var unexpected = MfaHeaderMessage(
            title: text("mfa.errors.unexpected.title", "Sign in couldn't be completed."),
            description: text("mfa.errors.unexpected.description",
                              "We are unable to process your request. Please try again in a few minutes."))
        /// The error screen's exit in Embedded Login.
        public var startOver = text("mfa.errors.startOver", "Start over")
        /// The error screen's exit in a step-up sheet.
        public var close = text("mfa.errors.close", "Close")

        /// The copy for `error`. An `unexpected` error that carries its own message shows that instead.
        func message(for error: MfaError) -> MfaHeaderMessage {
            switch error {
            case .cancelled: return cancelled
            case .tokenExpired: return tokenExpired
            case .tokenInvalid: return tokenInvalid
            case .maxChallengesExceeded: return maxChallengesExceeded
            case .rejected: return rejected
            case .tooManyAttempts: return tooManyAttempts
            case .noEligibleFactors: return noEligibleFactors
            case .network: return network
            case .credentialsNotSaved: return credentialsNotSaved
            case .presentationUnavailable: return unexpected
            case let .unexpected(message):
                guard let message else { return unexpected }
                return MfaHeaderMessage(title: unexpected.title, description: message)
            }
        }
    }
}

// swiftlint:enable nesting cyclomatic_complexity
