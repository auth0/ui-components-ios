@testable import Auth0UniversalComponents
import SwiftUI
import Testing

#if os(iOS)
import UIKit

/// The toast is laid out for real and asked whether its message needs a second line, for text where the height of a
/// line is not the height of an "A": other scripts, emoji, a long address with no spaces.
@MainActor
@Suite
struct ToastWrapMeasurementTests {

    private final class Reported {
        var metrics = ToastTextMetrics()
    }

    private func metrics(for message: String, width: CGFloat = 370) async throws -> ToastTextMetrics {
        let reported = Reported()
        let view = Auth0ToastView(message)
            .onPreferenceChange(ToastTextMetricsKey.self) { reported.metrics = $0 }
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        for _ in 0..<5 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        window.isHidden = true
        return reported.metrics
    }

    @Test(arguments: ["Account created", "Phone number verified", "メールアドレスを確認しました", "تم التحقق من البريد", "Done 🎉✅"])
    func aShortMessage_inAnyScript_isOneLine(message: String) async throws {
        let measured = try await metrics(for: message)
        #expect(measured.text > 0 && measured.oneLine > 0, "nothing was measured for \(message)")
        #expect(!measured.wraps, "\(message): \(measured.text) vs \(measured.oneLine)")
    }

    @Test(arguments: [
        "Account created. You can now log in with your email or phone number.",
        "アカウントを作成しました。メールアドレスまたは電話番号でログインできます。",
        "تم إنشاء الحساب بنجاح. يمكنك الآن تسجيل الدخول باستخدام بريدك الإلكتروني أو رقم هاتفك.",
        "Verified 🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅🎉✅"
    ])
    func aLongMessage_inAnyScript_wraps(message: String) async throws {
        let measured = try await metrics(for: message)
        #expect(measured.wraps, "\(message): \(measured.text) vs \(measured.oneLine)")
    }
}
#endif
