import SwiftUI
import Combine

/// A type-safe, observable navigation controller backed by SwiftUI's `NavigationPath`.
///
/// `Router` is the single source of truth for push navigation within a `NavigationStack`.
/// Bind it to a stack's `path` parameter and call `navigate(to:)` / `pop()` from any
/// view that has access to the router via `@EnvironmentObject`.
///
/// **Standalone usage** (SDK-owned stack):
/// ```swift
/// @StateObject private var router = Router<Route>()
///
/// NavigationStack(path: $router.path) {
///     RootView()
///         .navigationDestination(for: Route.self) { ViewFactory.view(for: $0) }
/// }
/// .environmentObject(router)
/// ```
///
/// **Embedded usage** (host-app stack):
/// When `MyAccountAuthMethodsView` runs inside a host `NavigationStack`, call
/// `useExternalPath(_:)` to redirect all navigation onto the host path. See
/// `NavigationEnvironment` for the full setup.
public class Router<Route: Hashable>: ObservableObject {

    /// The current navigation stack, bound directly to a `NavigationStack(path:)`.
    ///
    /// In embedded mode this property is not observed by any stack — navigation
    /// is redirected to the host path via `useExternalPath(_:)`.
    @Published public var path = NavigationPath()

    /// The host app's `NavigationPath` binding, set when running in embedded mode.
    ///
    /// `nil` in standalone mode; set via `useExternalPath(_:)` at view appearance.
    private var externalPath: Binding<NavigationPath>?

    /// Snapshot of the host path depth at the moment `useExternalPath(_:)` was called.
    ///
    /// Used by `popToSDKRoot()` to determine how many entries the SDK itself has
    /// appended, so only those are removed without disturbing host-app entries.
    private var initialExternalPathCount = 0

    public init() {}

    /// Redirects all navigation operations to an external `NavigationPath` binding.
    ///
    /// Call this once from the view's `.onAppear` when the router operates inside
    /// a host `NavigationStack`. All subsequent calls to `navigate(to:)`, `pop()`,
    /// and `popToRoot()` will target `binding` instead of the internal `path`.
    ///
    /// - Parameter binding: A writable binding to the host stack's `NavigationPath`.
    func useExternalPath(_ binding: Binding<NavigationPath>) {
        externalPath = binding
        initialExternalPathCount = binding.wrappedValue.count
    }

    /// Pushes `route` onto the navigation stack.
    ///
    /// - Parameter route: The destination to navigate to. Must match a registered
    ///   `.navigationDestination(for:)` in the enclosing `NavigationStack`.
    public func navigate(to route: Route) {
        if let ext = externalPath {
            ext.wrappedValue.append(route)
        } else {
            path.append(route)
        }
    }

    /// Pops the top destination off the navigation stack.
    ///
    /// No-ops when the stack is already at the root.
    public func pop() {
        if let ext = externalPath {
            guard !ext.wrappedValue.isEmpty else { return }
            ext.wrappedValue.removeLast()
        } else {
            guard !path.isEmpty else { return }
            path.removeLast()
        }
    }

    /// Pops only the routes pushed by the SDK, returning to `MyAccountAuthMethodsView`.
    ///
    /// In standalone mode, clears the entire internal path so the root content
    /// (`MyAccountAuthMethodsView`) is shown.
    /// In embedded mode, only removes entries added since `useExternalPath(_:)` was
    /// called, leaving the host-app entries intact so the host stack is undisturbed.
    func popToSDKRoot() {
        if let ext = externalPath {
            let toRemove = ext.wrappedValue.count - initialExternalPathCount
            guard toRemove > 0 else { return }
            ext.wrappedValue.removeLast(toRemove)
        } else {
            path.removeLast(path.count)
        }
    }
}
