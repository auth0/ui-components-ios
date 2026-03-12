import SwiftUI

// MARK: - Environment Keys

private struct EmbeddedInNavigationStackKey: EnvironmentKey {
    static let defaultValue = false
}

private struct HostNavigationPathKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationPath> = .constant(NavigationPath())
}

extension EnvironmentValues {

    /// Whether `MyAccountAuthMethodsView` is running inside a host app's `NavigationStack`.
    ///
    /// When `true`, the SDK skips creating its own `NavigationStack` and instead
    /// registers navigation destinations directly in the enclosing host stack.
    /// This prevents the SwiftUI bug where a `NavigationStack` pushed as a
    /// destination inside another `NavigationStack` is immediately dismissed.
    ///
    /// Set this via `.embeddedInNavigationStack()` rather than writing to this
    /// key directly.
    var isEmbeddedInNavigationStack: Bool {
        get { self[EmbeddedInNavigationStackKey.self] }
        set { self[EmbeddedInNavigationStackKey.self] = newValue }
    }

    /// A binding to the host app's `NavigationPath`.
    ///
    /// The SDK reads this in embedded mode so that `Router.navigate(to:)` appends
    /// SDK `Route` values onto the **host** stack's path rather than an internal
    /// path that nobody observes.
    ///
    /// Inject it on your root `NavigationStack`:
    ///
    /// ```swift
    /// NavigationStack(path: $router.path) { ... }
    ///     .environment(\.hostNavigationPath, $router.path)
    /// ```
    public var hostNavigationPath: Binding<NavigationPath> {
        get { self[HostNavigationPathKey.self] }
        set { self[HostNavigationPathKey.self] = newValue }
    }
}

// MARK: - View Modifier

extension View {

    /// Configures `MyAccountAuthMethodsView` for use inside a host `NavigationStack`.
    ///
    /// Apply this modifier in your navigation destination handler whenever you push
    /// `MyAccountAuthMethodsView` from within an existing `NavigationStack`:
    ///
    /// ```swift
    /// // 1. Inject the path binding once at the root NavigationStack
    /// NavigationStack(path: $router.path) {
    ///     RootView()
    ///         .navigationDestination(for: AppRoute.self) { route in
    ///             switch route {
    ///             case .loginSecurity:
    ///                 MyAccountAuthMethodsView()
    ///                     .embeddedInNavigationStack()  // ← required
    ///             }
    ///         }
    /// }
    /// .environment(\.hostNavigationPath, $router.path)  // ← required
    /// ```
    ///
    /// **What this does:**
    /// - Sets `isEmbeddedInNavigationStack = true` so the SDK does not create a
    ///   nested `NavigationStack` (which SwiftUI silently dismisses on push).
    /// - The SDK router redirects at runtime to append SDK routes onto the
    ///   host path supplied via `.environment(\.hostNavigationPath, ...)`.
    ///
    /// - Important: You must call `.environment(\.hostNavigationPath, $router.path)`
    ///   on the enclosing `NavigationStack`. Without it the SDK has no path to
    ///   write to, so tapping auth-method cards has no effect.
    public func embeddedInNavigationStack() -> some View {
        self.environment(\.isEmbeddedInNavigationStack, true)
    }
}
