import SwiftUI

/// Renders the coordinator's step, animates screen changes and owns the nav bar. The entry, code and error screens are
/// the login's own (`LoginIdentifierScreen`, `LoginCodeScreen`, `LoginErrorScreen`), with sign-up's words; the
/// rest (`SignupDeliveryScreen`) is sign-up's.
struct SignupRenderingHostView: View {
    @StateObject private var coordinator: SignupFlowCoordinator
    @Environment(\.auth0Theme) private var theme
    @Environment(\.embeddedEntry) private var entry
    @Environment(\.dismiss) private var dismiss

    /// Held locally so screen changes can be committed inside `withAnimation`.
    @State private var displayed: SignupStep = .loading
    @State private var transition = ScreenTransition()
    private let motion = ScreenMotion()

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
                .transition(transition.transition)
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
            transition.start(at: displayed.depth)
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

        case let .chooseDelivery(choice):
            SignupDeliveryScreen(sentTo: choice.challenge.sentTo ?? choice.identifier.value,
                                 ways: choice.challenge.deliveries, isLoading: coordinator.isSubmitting,
                                 errorMessage: coordinator.inputError?.message(for: choice.identifier.kind),
                                 onEdit: handleBack, onContinue: { send(.chooseDelivery($0)) })

        case let .collectCode(code):
            LoginCodeScreen(subtitle: code.subtitle, subtitleLineLimit: nil, isLoading: coordinator.isSubmitting,
                            errorMessage: coordinator.inputError?.message(for: code.identifier.kind),
                            isCodeExpired: code.isExpired, onVerify: { send(.submitCode($0)) },
                            onEdit: handleBack, onResend: { send(.resend) })

        case .authenticated:
            LoginSuccessScreen()

        case .unavailable:
            LoginErrorScreen(message: "This app can't create accounts right now.", title: "Sign-up isn't available",
                             retryTitle: "Go back") { leaveFlow() }

        case let .failed(message, canRetry):
            LoginErrorScreen(message: message, title: "Sign-up couldn't be completed.",
                             retryTitle: canRetry ? "Try again" : "Start over") { send(canRetry ? .retry : .restart) }
        }
    }

    /// The login's own entry screen for the kind's field, with sign-up's words.
    private func identifierScreen(_ kind: SignupIdentifierKind) -> some View {
        LoginIdentifierScreen(channel: kind.channel, alternatives: [],
                              prefill: coordinator.entered.flatMap { $0.kind == kind ? $0.loginIdentifier : nil },
                              isLoading: coordinator.isSubmitting,
                              errorMessage: coordinator.inputError?.message(for: kind),
                              title: entry.messages.signUpTitle, accountLink: backToLogin == nil ? nil : .logIn,
                              onAccountLink: { backToLogin?() },
                              onContinue: {
                                  send(.submitIdentifier(SignupIdentifierValue(kind: kind, value: $0.value)))
                              })
    }

    // MARK: Transitions

    /// A new screen animates as push or pop; a change inside the same screen updates in place (keeps focus).
    private func syncDisplay(to target: SignupStep) {
        guard target.identity != displayed.identity else {
            displayed = target
            return
        }
        transition.move(to: target.depth)
        withAnimation(motion.animation) { displayed = target }
        announceScreenChange(to: target)
    }

    /// Moves VoiceOver to the new screen. The failure and success screens have no field to take focus, so
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

    // MARK: Navigation

    private func handleBack() {
        switch coordinator.goBack() {
        case .exitFlow: leaveFlow()
        case .movedBack, .ignored: break
        }
    }

    /// Back to the login when sign-up was opened from it, else out of the flow.
    private func leaveFlow() {
        if let backToLogin { backToLogin() } else { dismiss() }
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
        case .chooseDelivery: return "delivery"
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
        case .chooseDelivery: return 2
        case .collectCode: return 3
        case .authenticated, .unavailable, .failed: return 4
        }
    }
}
