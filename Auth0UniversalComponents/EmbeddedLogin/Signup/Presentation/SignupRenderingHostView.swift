import Auth0
import SwiftUI

/// Renders the coordinator's step, animates screen changes and owns the nav bar. The screens are the login's own
/// (`LoginEmailScreen`, `LoginCodeScreen`, `LoginErrorScreen`), with sign-up's words.
struct SignupRenderingHostView: View {
    @StateObject private var coordinator: SignupFlowCoordinator
    @Environment(\.auth0Theme) private var theme
    @Environment(\.embeddedEntry) private var entry
    @Environment(\.dismiss) private var dismiss

    /// Held locally so screen changes can be committed inside `withAnimation`.
    @State private var displayed: SignupStep = .loading
    @State private var lastDepth = 0
    /// Push (deeper) vs. pop (shallower).
    @State private var forward = true

    #if !os(macOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif

    /// Set when sign-up was opened from the login: the entry screen then offers "Log in", and Back from it returns
    /// there instead of leaving the flow.
    private let backToLogin: (() -> Void)?

    /// `interactor` is built once, with the coordinator: a parent re-rendering doesn't build another.
    init(interactor: @autoclosure @escaping () -> any SignupInteracting, backToLogin: (() -> Void)? = nil) {
        _coordinator = StateObject(wrappedValue: SignupFlowCoordinator(interactor: interactor()))
        self.backToLogin = backToLogin
    }

    var body: some View {
        ZStack {
            theme.colors.background.layerBase.ignoresSafeArea()
            screen(for: displayed)
                .id(displayed.identity)
                .transition(pushTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(HorizontalClip())
        .safeAreaInset(edge: .top, spacing: 0) {
            LoginNavigationBar(title: "Sign up", isBackEnabled: !coordinator.isSubmitting, onBack: handleBack)
        }
        .systemNavigationBarHidden()
        .task { await coordinator.send(.start) }
        .onAppear {
            displayed = coordinator.step
            lastDepth = displayed.depth
        }
        .onChangeCompat(of: coordinator.step) { syncDisplay(to: $0) }
    }

    // MARK: Screens

    @ViewBuilder
    private func screen(for step: SignupStep) -> some View {
        switch step {
        case .loading:
            LoginLoadingScreen()

        case let .collectIdentifier(kind):
            identifierScreen(kind)

        case let .collectCode(code):
            LoginCodeScreen(
                subtitle: "Sent to \(code.identifier.value)",
                subtitleLineLimit: nil,
                isLoading: coordinator.isSubmitting,
                errorMessage: coordinator.inputError?.message,
                onVerify: { send(.submitCode($0)) },
                onEdit: handleBack,
                onResend: { send(.resend) })

        case .confirm:
            verifiedScreen

        case .authenticated:
            LoginSuccessScreen()

        case .unavailable:
            LoginErrorScreen(message: "This app can't create accounts right now.", title: "Sign-up isn't available",
                             retryTitle: "Go back") { dismiss() }

        case let .failed(message, canRetry):
            LoginErrorScreen(message: message, title: "Sign-up couldn't be completed.",
                             retryTitle: canRetry ? "Try again" : "Start over") { send(canRetry ? .retry : .restart) }
        }
    }

    private var verifiedScreen: some View {
        let kind = coordinator.entered?.kind ?? .email
        return SignupVerifiedScreen(
            title: kind.verifiedTitle, message: kind.verifiedMessage,
            isLoading: coordinator.isSubmitting, errorMessage: coordinator.inputError?.message,
            onPrimary: { send(.confirm) })
    }

    @ViewBuilder
    private func identifierScreen(_ kind: SignupIdentifierKind) -> some View {
        switch kind {
        case .email:
            LoginIdentifierScreen(channel: .email, alternatives: [],
                                  prefill: coordinator.entered.map { .email($0.value) },
                                  isLoading: coordinator.isSubmitting, errorMessage: coordinator.inputError?.message,
                                  title: entry.messages.signUpTitle, accountLink: backToLogin == nil ? nil : .logIn,
                                  onAccountLink: { backToLogin?() },
                                  onContinue: { send(.submitIdentifier(SignupIdentifierValue(kind: .email,
                                                                                           value: $0.value))) })
        }
    }

    // MARK: Transitions

    /// A new screen animates as push or pop; a change inside the same screen updates in place (keeps focus).
    private func syncDisplay(to target: SignupStep) {
        guard target.identity != displayed.identity else {
            displayed = target
            return
        }
        forward = target.depth >= lastDepth
        lastDepth = target.depth
        withAnimation(motionEnabled ? .easeInOut(duration: 0.28) : nil) { displayed = target }
        announceScreenChange(to: target)
    }

    /// Moves VoiceOver to the new screen. The confirm, failure and success screens have no field to take focus, so
    /// without this it stays on a control that is gone, and an outcome is never read out.
    private func announceScreenChange(to step: SignupStep) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        switch step {
        case let .failed(message, _): UIAccessibility.post(notification: .announcement, argument: message)
        case .unavailable: UIAccessibility.post(notification: .announcement, argument: "Sign-up isn't available")
        case .authenticated: UIAccessibility.post(notification: .announcement, argument: "You're signed in")
        default: break
        }
        #endif
    }

    private var pushTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    private var motionEnabled: Bool {
        #if !os(macOS)
        return !reduceMotion
        #else
        return true
        #endif
    }

    // MARK: Navigation

    private func handleBack() {
        switch coordinator.goBack() {
        case .exitFlow: if let backToLogin { backToLogin() } else { dismiss() }
        case .movedBack, .ignored: break
        }
    }

    private func send(_ event: SignupEvent) {
        Task { await coordinator.send(event) }
    }
}

private extension SignupStep {
    /// Names the screen, ignoring what it carries, so a change in its payload doesn't transition.
    var identity: String {
        switch self {
        case .loading: return "loading"
        case let .collectIdentifier(kind): return "identifier.\(kind)"
        case .collectCode: return "code"
        case .confirm: return "confirm"
        case .authenticated: return "authenticated"
        case .unavailable: return "unavailable"
        case .failed: return "failed"
        }
    }

    /// Compared across a change to pick a push (deeper) or pop (shallower).
    var depth: Int {
        switch self {
        case .loading: return 0
        case .collectIdentifier: return 1
        case .collectCode: return 2
        case .confirm: return 3
        case .authenticated, .unavailable, .failed: return 4
        }
    }
}
