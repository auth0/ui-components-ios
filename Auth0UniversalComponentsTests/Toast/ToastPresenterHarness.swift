@testable import Auth0UniversalComponents
import Foundation

/// A presenter on a manual clock, with what it announced and what it cleared recorded.
@MainActor
final class ToastPresenterHarness {
    let clock = ManualToastClock()
    let sut: ToastPresenter
    private(set) var announced: [String] = []
    private(set) var cleared: [UUID] = []

    init(hostVisible: Bool = true) {
        var announce: ((String) -> Void)?
        sut = ToastPresenter(sleeper: clock, announce: { announce?($0) })
        announce = { [unowned self] in self.announced.append($0) }
        // As the modifier does: clearing empties the app's binding, and the change comes back as `sync(nil)`.
        sut.clear = { [unowned self] id in
            self.cleared.append(id)
            self.sut.sync(nil)
        }
        if hostVisible { sut.hostAppeared() }
    }

    /// The app sets the binding, and the modifier tells the presenter.
    func show(_ message: Auth0ToastMessage?) async {
        sut.sync(message)
        await clock.settle()
    }
}
