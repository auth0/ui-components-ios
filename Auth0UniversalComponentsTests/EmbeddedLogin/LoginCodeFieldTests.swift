#if canImport(UIKit)
@testable import Auth0UniversalComponents
import SwiftUI
import Testing
import UIKit

@Suite
@MainActor
struct LoginCodeFieldTests {

    private func boxes(isEnabled: Bool) -> [UITextField] {
        let host = UIHostingController(rootView: LoginCodeField(code: .constant("123"), isEnabled: isEnabled))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        func all(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(all) }
        return all(host.view).compactMap { $0 as? UITextField }
    }

    @Test func whileVerifying_noBoxCanBeFocusedOrEdited() {
        let fields = boxes(isEnabled: false)
        #expect(fields.count == 6)
        #expect(fields.allSatisfy { !$0.isEnabled && !$0.canBecomeFirstResponder },
                "allowsHitTesting only stops touches; VoiceOver and a keyboard could still edit")
    }

    @Test func otherwise_everyBoxCanBeFocused() {
        let fields = boxes(isEnabled: true)
        #expect(fields.count == 6)
        #expect(fields.allSatisfy { $0.isEnabled && $0.canBecomeFirstResponder })
    }
}
#endif
