#if os(iOS)
@testable import Auth0UniversalComponents
import Foundation
import SwiftUI
import Testing
import UIKit

/// The screens scroll when the keyboard or large text leaves too little room, and sit still when everything fits.
/// Hosted in a real window so the system lays them out. iOS only: that is where a keyboard covers the screen, and a
/// window made without a scene crashes the visionOS test host.
@Suite
@MainActor
struct LoginScreenScrollTests {

    private let passwordScreen = LoginPasswordScreen(
        username: "sarah.doe@atko.email", identifierLabel: "Email", onContinue: { _ in }, onEdit: {}, onSendCode: {},
        sendCodeTitle: "Email me a code")
    private let passwordOnlyScreen = LoginPasswordScreen(username: "sarah.doe", onContinue: { _ in }, onEdit: {})
    private let codeScreen = LoginCodeScreen(
        subtitle: "From sarah.doe@atko.email", onVerify: { _ in }, onEdit: {}, onResend: {}, onUsePassword: {})
    private let firstScreen = LoginIdentifierScreen(channel: .phone, alternatives: [.email, .password],
                                                    onContinue: { _ in }, onChoose: { _ in })
    private let emailScreen = LoginEmailScreen { _ in }

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

    @Test func theCodeScreen_sitsStill_whenItFits() async throws {
        let scrollView = try #require(await scrollView(of: codeScreen, size: CGSize(width: 390, height: 844)))
        #expect(scrollView.contentSize.height <= scrollView.bounds.height + 1)
    }

    @Test func thePasswordScreenWithNoCodeOffered_scrollsToo_andSitsStillWhenItFits() async throws {
        let short = try #require(await scrollView(of: passwordOnlyScreen, size: CGSize(width: 375, height: 260)))
        #expect(short.contentSize.height > short.bounds.height + 20)
        let tall = try #require(await scrollView(of: passwordOnlyScreen, size: CGSize(width: 390, height: 844)))
        #expect(tall.contentSize.height <= tall.bounds.height + 1)
    }

    @Test func theFirstScreen_withTwoAlternatives_scrollsWhenShortOfRoom() async throws {
        let scrollView = try #require(await scrollView(of: firstScreen, size: CGSize(width: 375, height: 330)))
        #expect(scrollView.contentSize.height > scrollView.bounds.height + 20)
    }

    @Test func theEmailScreen_sitsStill_whenItFits() async throws {
        let scrollView = try #require(await scrollView(of: emailScreen, size: CGSize(width: 390, height: 844)))
        #expect(scrollView.contentSize.height <= scrollView.bounds.height + 1)
    }
}
#endif
