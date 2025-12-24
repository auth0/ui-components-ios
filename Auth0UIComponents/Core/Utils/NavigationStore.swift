import Combine
import Foundation

@MainActor
final class NavigationStore: ObservableObject {
    @Published var path: [Route] = []
    private let popToRootSubject = PassthroughSubject<Void, Never>()

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

    var popDataRefreshPublisher: AnyPublisher<Void, Never> {
        Publishers.Merge(popToRootSubject.eraseToAnyPublisher(), $path
            .scan((previous: [Route](), current: [Route]())) { state, newPath in
                (previous: state.current, current: newPath)
            }
            .filter { $0.current.count < $0.previous.count }
            .map { _ in () }
            .eraseToAnyPublisher())
        .eraseToAnyPublisher()
    }

    func popToRoot() {
        path.removeAll()
        popToRootSubject.send(())
    }

    func reset() {
        path = []
    }
}
