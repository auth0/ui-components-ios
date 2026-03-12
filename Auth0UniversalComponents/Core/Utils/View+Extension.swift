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

    /// Presents a modal cover using `fullScreenCover` on iOS and visionOS,
    /// falling back to `sheet` on macOS where `fullScreenCover` is unavailable.
    ///
    /// Use this instead of `.fullScreenCover` anywhere the target includes macOS.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that drives presentation.
    ///   - content: The view to present.
    @ViewBuilder
    func fullScreenCoverOrSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        self.sheet(isPresented: isPresented, content: content)
        #else
        self.fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}

// MARK: - Cross-platform toolbar placement

extension ToolbarItemPlacement {
    /// The leading bar placement on each platform:
    /// - iOS / visionOS: `.topBarLeading`
    /// - macOS: `.navigation`
    ///
    /// Use this instead of `.navigationBarLeading` or `.topBarLeading` directly
    /// in any view that targets more than one Apple platform.
    public static var platformLeading: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarLeading
        #endif
    }
}
