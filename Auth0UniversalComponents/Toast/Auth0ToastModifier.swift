import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension View {

    /// Shows a success toast over this view whenever `message` is set, and clears `message` when it goes away.
    ///
    /// The toast sits at the top of the screen, 8 pt below the safe area, over the content: it never moves it.
    /// Only one shows at a time, so setting a new message replaces the current one. It slides down and fades in
    /// over 250 ms, rests 4 s (1 s more for a second line, at least 6 s while VoiceOver is running), then fades out
    /// over 200 ms. A swipe up dismisses it early. With Reduce Motion on it only fades.
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
    /// - Parameter message: The toast to show, or `nil` for none.
    func auth0Toast(_ message: Binding<Auth0ToastMessage?>) -> some View {
        modifier(Auth0ToastModifier(message: message))
    }
}

struct Auth0ToastModifier: ViewModifier {

    @Binding var message: Auth0ToastMessage?

    @Environment(\.auth0Theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning

    @State private var lineCount = 1
    @State private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // The ZStack is empty, and so takes no touches, while there is no toast.
            ZStack {
                if let message {
                    Auth0ToastView(message.text)
                        .padding(.horizontal, theme.spacing.md)
                        .padding(.top, theme.spacing.xs)
                        .offset(y: dragOffset)
                        .gesture(swipeToDismiss)
                        .onPreferenceChange(ToastTextMetricsKey.self) { lineCount = $0.lineCount }
                        .id(message.id)
                        .transition(transition)
                        .task(id: message.id) { await run(message) }
                }
            }
            .animation(animation, value: message)
        }
    }

    private var animation: Animation {
        message == nil
            ? .easeIn(duration: ToastBehavior.disappearDuration)
            : .easeOut(duration: ToastBehavior.appearDuration)
    }

    /// In: slide down and fade. Out: fade. With Reduce Motion, only the fade.
    private var transition: AnyTransition {
        let fade = AnyTransition.opacity
        let insertion = reduceMotion ? fade : fade.combined(with: .offset(y: -ToastBehavior.slideDistance))
        return .asymmetric(insertion: insertion, removal: fade)
    }

    private var swipeToDismiss: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = min(0, $0.translation.height) }
            .onEnded { value in
                if ToastBehavior.shouldDismiss(swipe: value.translation.height) {
                    message = nil
                } else {
                    withAnimation(.easeOut(duration: ToastBehavior.appearDuration)) { dragOffset = 0 }
                }
            }
    }

    /// Announces the toast, lets it rest, and clears it. Cancelled, so never clearing a newer toast, when it is
    /// replaced or dismissed.
    @MainActor
    private func run(_ shown: Auth0ToastMessage) async {
        dragOffset = 0
        announce(shown.text)
        // The line count is known once the toast has been laid out, which the fade-in outlasts.
        await sleep(ToastBehavior.appearDuration)
        let hold = ToastBehavior.hold(lines: lineCount, voiceOverRunning: voiceOverRunning)
        await sleep(hold)
        guard !Task.isCancelled, message == shown else { return }
        message = nil
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Has VoiceOver read the toast without moving focus to it.
    private func announce(_ text: String) {
        if #available(iOS 17, macOS 14, visionOS 1, *) {
            AccessibilityNotification.Announcement(text).post()
        } else {
            #if canImport(UIKit)
            UIAccessibility.post(notification: .announcement, argument: text)
            #endif
        }
    }
}
