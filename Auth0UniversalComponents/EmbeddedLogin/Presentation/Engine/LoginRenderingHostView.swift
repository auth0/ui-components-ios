import SwiftUI

/// Renders the coordinator's step, animates screen changes and owns the nav bar.
struct LoginRenderingHostView: View {
    @StateObject private var coordinator: LoginFlowCoordinator
    @Environment(\.auth0Theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Kept on screen (with a button spinner) while the coordinator is `.loading` mid-flow.
    @State private var lastInputStep: LoginStep?

    /// Held locally so screen changes can be committed inside `withAnimation`.
    @State private var displayedPlan: ScreenPlan = .loading

    @State private var lastDepth = 0
    /// Push (deeper) vs. pop (shallower).
    @State private var forward = true

    #if !os(macOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif

    private let renderer = LoginRenderer() // TODO: Move into a view model.

    /// Called once credentials are stored in the Keychain.
    private let onAuthenticated: () -> Void

    /// `interactor` is built once, with the coordinator: a parent re-rendering doesn't build another.
    init(interactor: @autoclosure @escaping () -> any AuthInteracting, additionalStep: AdditionalStepProviding? = nil,
         onAuthenticated: @escaping () -> Void = {}) {
        _coordinator = StateObject(
            wrappedValue: LoginFlowCoordinator(interactor: interactor(), additionalStep: additionalStep))
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        ZStack {
            theme.colors.background.layerBase.ignoresSafeArea()
            renderer.view(for: displayedPlan, context: context)
                .id(displayedPlan.transitionIdentity)
                .transition(pushTransition)
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
            lastDepth = displayedPlan.navigationDepth
        }
        .onChangeCompat(of: coordinator.step) { newStep in
            trackInputStep(newStep)
            if case .authenticated = newStep { onAuthenticated() }
            syncDisplay()
        }
    }

    // MARK: Engine wiring

    private var displayStep: LoginStep {
        if case .loading = coordinator.step, let lastInputStep { return lastInputStep }
        return coordinator.step
    }

    private var currentPlan: ScreenPlan {
        renderer.plan(for: displayStep)
    }

    private var context: RenderContext {
        RenderContext(
            additionalStepView: coordinator.additionalStep?.view,
            email: coordinator.enteredEmail,
            isSubmitting: coordinator.isSubmitting,
            inputError: coordinator.inputError,
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
        let newDepth = target.navigationDepth
        forward = newDepth >= lastDepth
        lastDepth = newDepth
        withAnimation(motionEnabled ? .easeInOut(duration: 0.28) : nil) {
            displayedPlan = target
        }
    }

    private var pushTransition: AnyTransition {
        let insertionEdge: Edge = forward ? .trailing : .leading
        let removalEdge: Edge = forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
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
        case .exitFlow: dismiss()
        case .movedBack, .ignored: break
        }
    }

    private func trackInputStep(_ step: LoginStep) {
        switch step {
        case .collectOTPIdentifier, .collectOTPCode:
            lastInputStep = step
        case .loading:
            break
        default:
            lastInputStep = nil
        }
    }

    private func send(_ event: LoginEvent) {
        Task { await coordinator.send(event) }
    }
}

/// Clips horizontally, unbounded vertically.
private struct HorizontalClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -10_000))
    }
}
