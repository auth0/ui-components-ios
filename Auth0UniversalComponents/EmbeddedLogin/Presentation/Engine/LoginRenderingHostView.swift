import SwiftUI

/// Renders the coordinator's step, animates screen changes and owns the nav bar.
struct LoginRenderingHostView: View {
    @StateObject private var coordinator: LoginFlowCoordinator
    @Environment(\.auth0Theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Held locally so screen changes can be committed inside `withAnimation`.
    @State private var displayedPlan: ScreenPlan = .loading

    /// A move between two ways of finishing the same step (code and password) is a cross-fade, not a push.
    @State private var transition = ScreenTransition()
    private let motion = ScreenMotion()

    /// Stateless, so the host owns one; the decisions it makes are covered by `LoginRendererTests`.
    private let renderer = LoginRenderer()

    /// Builds sign-up, shown over the login. It is given what returns to the login. `nil` offers no sign-up. The host
    /// knows nothing about sign-up itself: whoever builds it says what it is.
    private let makeSignup: ((_ backToLogin: @escaping () -> Void) -> AnyView)?
    @State private var isShowingSignup = false

    /// `interactor` is built once, with the coordinator: a parent re-rendering doesn't build another.
    init(interactor: @autoclosure @escaping () -> any AuthInteracting, additionalStep: AdditionalStepProviding? = nil,
         makeSignup: ((_ backToLogin: @escaping () -> Void) -> AnyView)? = nil) {
        _coordinator = StateObject(
            wrappedValue: LoginFlowCoordinator(interactor: interactor(), additionalStep: additionalStep))
        self.makeSignup = makeSignup
    }

    /// The login stays where it is while sign-up is over it, so coming back doesn't load it again.
    var body: some View {
        ZStack {
            loginBody
                .accessibilityHidden(isShowingSignup)
                .allowsHitTesting(!isShowingSignup)
            if isShowingSignup, let makeSignup {
                makeSignup { setSignupShown(false) }
                    .transition(.move(edge: .trailing))
            }
        }
    }

    private var loginBody: some View {
        ZStack {
            theme.colors.background.layerBase.ignoresSafeArea()
            renderer.view(for: displayedPlan, context: context)
                .id(displayedPlan.transitionIdentity)
                .transition(transition.transition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Horizontal only, so backgrounds still reach under the home indicator.
        .clipShape(HorizontalClip())
        .safeAreaInset(edge: .top, spacing: 0) {
            LoginNavigationBar(title: "Log in", isBackEnabled: !coordinator.isSubmitting, onBack: handleBack)
        }
        .systemNavigationBarHidden()
        .task {
            await coordinator.send(.start)
        }
        .onAppear {
            displayedPlan = currentPlan
            transition.start(at: displayedPlan.navigationDepth)
        }
        .onChangeCompat(of: coordinator.step) { _ in syncDisplay() }
    }

    // MARK: Engine wiring

    private var currentPlan: ScreenPlan {
        renderer.plan(for: coordinator.displayedStep, channels: coordinator.channels)
    }

    private var context: RenderContext {
        let signUp: (() -> Void)? = coordinator.canSignUp && makeSignup != nil ? { openSignup() } : nil
        return RenderContext(
            additionalStepView: coordinator.additionalStep?.view,
            identifier: coordinator.enteredIdentifier,
            signUp: signUp,
            isSubmitting: coordinator.isSubmitting,
            inputError: coordinator.inputError,
            codeAvailableAt: coordinator.codeAvailableAt(for: coordinator.enteredIdentifier),
            dispatch: { send($0) },
            resend: { Task { await coordinator.resendOTP() } },
            back: handleBack
        )
    }

    // MARK: Screen transitions

    /// A new screen animates as push/pop; a payload-only change updates in place (keeps focus).
    private func syncDisplay() {
        let target = currentPlan
        guard target.transitionIdentity != displayedPlan.transitionIdentity else {
            displayedPlan = target
            return
        }
        transition.move(to: target.navigationDepth, isSwap: target.isSibling(of: displayedPlan))
        withAnimation(motion.animation) {
            displayedPlan = target
        }
    }

    // MARK: Navigation

    private func handleBack() {
        switch coordinator.goBack() {
        case .exitFlow: dismiss()
        case .movedBack, .ignored: break
        }
    }

    private func openSignup() { setSignupShown(true) }

    private func setSignupShown(_ shown: Bool) {
        withAnimation(motion.animation) { isShowingSignup = shown }
    }

    private func send(_ event: LoginEvent) {
        Task { await coordinator.send(event) }
    }
}
