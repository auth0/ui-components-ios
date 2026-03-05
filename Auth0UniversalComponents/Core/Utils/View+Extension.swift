import SwiftUI

extension View {
    /// Attaches a toast notification modifier to the view.
    ///
    /// This convenience method applies the ToastModifier to display toast notifications
    /// on top of the view. Use this to add toast notification capability to any view.
    ///
    /// - Parameter toast: A binding to an optional Toast that controls whether the toast is displayed
    /// - Returns: A modified view with toast capability
    ///
    /// Example:
    /// ```swift
    /// @State var toast: Toast?
    ///
    /// VStack {
    ///   // Your content
    /// }
    /// .toastView(toast: $toast)
    /// ```
    func toastView(toast: Binding<Toast?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}
