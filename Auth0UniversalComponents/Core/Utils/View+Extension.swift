import SwiftUI

extension View {
    /// Applies a navigation title whose text colour adapts to the active Auth0 theme.
    ///
    /// SwiftUI's built-in `.navigationTitle` text colour is system-controlled and
    /// cannot be overridden via foreground modifiers. This helper keeps
    /// `.navigationTitle` so that child screens still show the correct back-button
    /// label, and additionally injects a `ToolbarItem(placement: .principal)` to
    /// render the title in `theme.colors.text.bold` using the theme typography.
    ///
    /// - Parameters:
    ///   - title: The navigation title string.
    ///   - theme: The active `Auth0Theme` to source the colour and typography from.
    @ViewBuilder
    func themedNavigationTitle(_ title: String, theme: Auth0Theme) -> some View {
        self
            .navigationTitle(title)
            #if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .auth0TextStyle(theme.typography.title)
                        .foregroundStyle(theme.colors.text.bold)
                }
            }
            #endif
    }

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
