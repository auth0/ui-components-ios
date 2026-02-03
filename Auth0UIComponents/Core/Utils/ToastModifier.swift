import SwiftUI

/// A view modifier that displays toast notifications on top of any view.
///
/// This modifier manages the display and automatic dismissal of toast notifications.
/// It handles the animation and timing for showing and hiding toasts.
///
/// Usage:
/// ```swift
/// @State var toast: Toast?
///
/// VStack {
///   // Your content
/// }
/// .modifier(ToastModifier(toast: $toast))
/// ```
struct ToastModifier: ViewModifier {
    /// The toast to display, or nil if no toast is visible
    @Binding var toast: Toast?
    /// Work item for scheduling the auto-dismiss
    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    mainToastView()
                        .offset(y: 20)
                }.animation(.spring(), value: toast)
            )
            .onChange(of: toast) { value in
                showToast()
            }
    }

    /// Creates the toast view if one is set.
    @ViewBuilder func mainToastView() -> some View {
        if let toast = toast {
            VStack {
                Spacer()
                ToastView(
                    style: toast.style,
                    message: toast.message
                ) {
                    dismissToast()
                }
            }
        }
    }

    /// Shows the toast and schedules its automatic dismissal based on duration.
    private func showToast() {
        guard let toast = toast else { return }

        if toast.duration > 0 {
            workItem?.cancel()

            let task = DispatchWorkItem {
                dismissToast()
            }

            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
        }
    }

    /// Hides the toast and cancels any pending dismissal.
    private func dismissToast() {
        withAnimation {
            toast = nil
        }

        workItem?.cancel()
        workItem = nil
    }
}
