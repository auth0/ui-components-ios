@testable import Auth0UniversalComponents
import Combine
import SwiftUI
import Testing

#if os(iOS)
import UIKit

/// The modifier on a real screen, with real timers: the wiring between the app's binding, the presenter and its clock
/// that the presenter's own tests can't reach. Times are short, and the checks have wide margins.
@MainActor
@Suite
struct ToastModifierWiringTests {

    private final class Model: ObservableObject {
        @Published var toast: Auth0ToastMessage?
    }

    private struct Screen: View {
        @ObservedObject var model: Model

        var body: some View {
            SwiftUI.Color.clear.auth0Toast($model.toast)
        }
    }

    private func show(_ model: Model) async throws -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = UIHostingController(rootView: Screen(model: model))
        window.makeKeyAndVisible()
        try await Task.sleep(nanoseconds: 100_000_000)
        return window
    }

    private func wait(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// The whole path: the binding is set, the toast shows and rests, and the binding is emptied by the presenter.
    @Test func aToast_restsItsDuration_thenEmptiesTheBinding() async throws {
        let model = Model()
        let window = try await show(model)
        defer { window.isHidden = true }

        model.toast = Auth0ToastMessage("Link copied", duration: 0.4)
        try await wait(0.3)
        #expect(model.toast != nil, "still in its time")

        try await wait(1.5)
        #expect(model.toast == nil, "emptied when its time was over")
    }

    @Test func aReplacedToast_isNotClearedByTheOldTimer() async throws {
        let model = Model()
        let window = try await show(model)
        defer { window.isHidden = true }

        model.toast = Auth0ToastMessage("First", duration: 0.3)
        try await wait(0.15)
        let second = Auth0ToastMessage("Second", duration: 2)
        model.toast = second

        try await wait(1.2)
        #expect(model.toast == second, "the first one's time ended; the second must stay")

        try await wait(2.5)
        #expect(model.toast == nil)
    }

    /// One toast at the top and the next at the bottom, on a screen whose default is the top: each is shown, replaces
    /// the last, and is cleared by its own time.
    @Test func toastsAtDifferentEdges_replaceEachOther() async throws {
        let model = Model()
        let window = try await show(model)
        defer { window.isHidden = true }

        model.toast = Auth0ToastMessage("Top", duration: 0.3)
        try await wait(0.15)
        let bottom = Auth0ToastMessage("Bottom", style: .notice, edge: .bottom, duration: 1.5)
        model.toast = bottom

        try await wait(1.0)
        #expect(model.toast == bottom, "the top toast's time ended; the bottom one must stay")
        try await wait(2.0)
        #expect(model.toast == nil)
    }

    /// The screen leaves: the toast goes with it, and doesn't return when the screen is shown again.
    @Test func aToast_doesNotReturnWhenTheScreenComesBack() async throws {
        let model = Model()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let screen = UIHostingController(rootView: Screen(model: model))
        window.rootViewController = screen
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await wait(0.2)

        model.toast = Auth0ToastMessage("Account created", duration: 30)
        try await wait(0.4)
        #expect(model.toast != nil)

        window.rootViewController = UIViewController()      // the screen goes
        try await wait(0.4)
        #expect(model.toast == nil, "cleared when the screen went")

        window.rootViewController = screen                  // and comes back
        try await wait(0.6)
        #expect(model.toast == nil, "not shown again")
    }
}
#endif
