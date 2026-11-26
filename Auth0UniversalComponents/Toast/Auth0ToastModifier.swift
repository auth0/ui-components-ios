import SwiftUI

public extension View {

    /// Shows a toast over this view whenever `message` is set, and clears `message` when it goes away.
    ///
    /// The toast sits at the top of the screen by default, 8 pt below the safe area, over the content: it never
    /// moves it. Pass `.bottom` to show it at the bottom instead; it then comes in from below, and a swipe down
    /// dismisses it. A message can choose its own edge, which wins over this one.
    ///
    /// Only one shows at a time, so setting a new message replaces the current one. It slides in and fades in over
    /// 250 ms, rests 4 s (1 s more for a second line, at least 6 s while VoiceOver is running), then fades out over
    /// 200 ms. A swipe away from its edge dismisses it early, and so does VoiceOver's escape gesture. With Reduce
    /// Motion on it only fades. A message can set its own look (``Auth0ToastStyle``) and its own resting time.
    ///
    /// The toast belongs to the screen it is shown on: it goes when that screen goes, and doesn't come back with it.
    /// Set the message on the screen the user lands on (the one after a push, or after a sheet closes), not on the one
    /// they are leaving, which would never show it.
    ///
    /// VoiceOver is sent an announcement of the message, and focus stays where it was.
    ///
    /// ```swift
    /// @State private var toast: Auth0ToastMessage?
    ///
    /// ContentView()
    ///     .auth0Toast($toast)
    ///
    /// // later
    /// toast = Auth0ToastMessage("Account created")
    /// ```
    ///
    /// - Parameters:
    ///   - message: The toast to show, or `nil` for none.
    ///   - edge: The edge of the screen toasts appear at when their message doesn't set one: `.top` (the default) or
    ///     `.bottom`.
    func auth0Toast(_ message: Binding<Auth0ToastMessage?>, edge: VerticalEdge = .top) -> some View {
        modifier(Auth0ToastModifier(message: message, edge: edge))
    }
}

struct Auth0ToastModifier: ViewModifier {

    @Binding var message: Auth0ToastMessage?
    let edge: VerticalEdge

    @Environment(\.auth0Theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning

    @State private var presenter = ToastPresenter()
    /// How far the finger has pulled the toast up. Back to 0 by itself, eased, when the drag ends or the system
    /// cancels it.
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: ToastBehavior.appearDuration)))
    private var pull: CGFloat = 0
    /// The toast a finger is on, so a toast that replaced it is never taken for dragged.
    @GestureState private var draggedToast: UUID?

    func body(content: Content) -> some View {
        // Kept current on every update: the binding can change with the app's own state. It holds the binding, not
        // this struct, which would keep the presenter and the app's state alive through the presenter's own closure.
        let binding = $message
        presenter.clear = { id in
            if binding.wrappedValue?.id == id { binding.wrappedValue = nil }
        }
        return content
            .overlay { toast }
            .onAppear { presenter.hostAppeared() }
            .onDisappear { presenter.hostDisappeared() }
            .task(id: message) { presenter.sync(message) }
            .task(id: voiceOverRunning) { presenter.voiceOverChanged(voiceOverRunning) }
    }

    private var toast: some View {
        // Each toast sits at its own edge, so one that is replaced fades out where it was. The ZStack and the frames
        // take no touches where there is no toast.
        ZStack {
            if let message {
                let edge = message.resolvedEdge(default: edge)
                Auth0ToastView(message.text, style: message.style)
                    .padding(.horizontal, theme.spacing.md)
                    .padding(edge == .top ? .top : .bottom, theme.spacing.xs)
                    .offset(y: pull)
                    .gesture(swipeToDismiss(message.id, edge: edge))
                    // Without a swipe: VoiceOver's escape gesture, and an action Switch Control and Voice Control list.
                    .accessibilityAction(.escape) { presenter.dismiss(id: message.id) }
                    .accessibilityAction(named: Text("Dismiss")) { presenter.dismiss(id: message.id) }
                    .onPreferenceChange(ToastTextMetricsKey.self) {
                        presenter.measured(wraps: $0.wraps, id: message.id)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .top ? .top : .bottom)
                    .id(message.id)
                    .task(id: draggedToast == message.id) {
                        presenter.dragChanged(active: draggedToast == message.id, id: message.id)
                    }
                    .transition(transition(edge))
            }
        }
        .animation(animation, value: message)
    }

    private var animation: Animation {
        message == nil
            ? .easeIn(duration: ToastBehavior.disappearDuration)
            : .easeOut(duration: ToastBehavior.appearDuration)
    }

    /// In: slide in from the edge and fade. Out: fade. With Reduce Motion, only the fade.
    private func transition(_ edge: VerticalEdge) -> AnyTransition {
        let fade = AnyTransition.opacity
        let insertion = reduceMotion ? fade : fade.combined(with: .offset(y: ToastBehavior.slideOffset(edge: edge)))
        return .asymmetric(insertion: insertion, removal: fade)
    }

    /// Built for one toast: what it ends can only dismiss that toast.
    private func swipeToDismiss(_ id: UUID, edge: VerticalEdge) -> some Gesture {
        DragGesture(minimumDistance: ToastBehavior.swipeStartDistance)
            .updating($pull) { value, state, _ in state = ToastBehavior.pull(value.translation.height, edge: edge) }
            .updating($draggedToast) { _, state, _ in state = id }
            .onEnded { presenter.dragEnded(id: id, translation: $0.translation.height, edge: edge) }
    }
}
