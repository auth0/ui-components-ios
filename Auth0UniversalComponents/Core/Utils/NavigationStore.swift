import Combine
import Foundation

/// Manages navigation state for Auth0 UI Components flows.
///
/// This store maintains the navigation path for the authentication method enrollment flows.
/// It is thread-safe and bound to the main thread. It uses a singleton pattern to ensure
/// a single source of truth for navigation throughout the app.
///
/// The store publishes path changes so SwiftUI views can react to navigation updates
/// and update their displayed content accordingly.
@MainActor
final class NavigationStore: ObservableObject {
    /// The current navigation path, representing the stack of routes
    @Published var path: [Route] = []

    /// The singleton instance of NavigationStore
    static let shared = NavigationStore()
    private init() {}

    /// Pushes a new route onto the navigation stack.
    ///
    /// - Parameter route: The route to navigate to
    func push(_ route: Route) {
        path.append(route)
    }

    /// Pops the top route from the navigation stack.
    ///
    /// Does nothing if the stack is empty.
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Clears the entire navigation stack, returning to the root.
    func popToRoot() {
        path.removeAll()
    }

    /// Resets the navigation store to its initial state.
    ///
    /// Primarily used for testing purposes.
    func reset() {
        path = []
    }
}
