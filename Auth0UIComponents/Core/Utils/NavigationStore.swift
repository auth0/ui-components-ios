import Combine
import Foundation

/// Singleton navigation store managing the navigation path for the application.
@MainActor
final class NavigationStore: ObservableObject {
    @Published var path: [Route] = []

    static let shared = NavigationStore()
    private init() {}

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path.removeAll()
    }

    func reset() {
        path = []
    }
}
