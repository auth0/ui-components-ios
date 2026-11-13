#if canImport(UIKit)
@testable import Auth0UniversalComponents
import Foundation
import SwiftUI
import Testing
import UIKit

/// The password and code screens scroll when the keyboard or large text leaves too little room, and sit still when
/// everything fits. Hosted in a real window so the system lays them out.
@Suite
@MainActor
struct LoginScreenScrollTests {

    private let passwordScreen = LoginPasswordScreen(
        username: "sarah.doe@atko.email", identifierLabel: "Email", onContinue: { _ in }, onEdit: {}, onSendCode: {},
        sendCodeTitle: "Email me a code")
    private let codeScreen = LoginCodeScreen(
        subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {}, onUsePassword: {})

    /// The scroll view of `screen` shown at `size`, once laid out.
    private func scrollView<Screen: View>(of screen: Screen, size: CGSize) async -> UIScrollView? {
        let controller = UIHostingController(rootView: screen)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        for _ in 0..<5 {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        return Self.firstScrollView(in: controller.view)
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    @Test func thePasswordScreen_scrolls_whenTheKeyboardLeavesTooLittleRoom() async throws {
        let scrollView = try #require(await scrollView(of: passwordScreen, size: CGSize(width: 375, height: 330)))
        #expect(scrollView.contentSize.height > scrollView.bounds.height + 20)
    }

    @Test func theCodeScreen_scrolls_whenTheKeyboardLeavesTooLittleRoom() async throws {
        let scrollView = try #require(await scrollView(of: codeScreen, size: CGSize(width: 375, height: 330)))
        #expect(scrollView.contentSize.height > scrollView.bounds.height + 20)
    }

    @Test func thePasswordScreen_sitsStill_whenItFits() async throws {
        let scrollView = try #require(await scrollView(of: passwordScreen, size: CGSize(width: 390, height: 844)))
        #expect(scrollView.contentSize.height <= scrollView.bounds.height + 1)
    }
}
#endif
