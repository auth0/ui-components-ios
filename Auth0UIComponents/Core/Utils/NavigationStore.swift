import Combine
import Foundation

@MainActor
final class NavigationStore: ObservableObject {
    @Published var path: [Route] = []

    static let shared = NavigationStore()
    private init() {}

    private let queue = DispatchQueue(label: "NavigationStoreQueue")

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func reset() {
        path = []
    }
}
