@testable import Auth0UniversalComponents
import ImageIO
import SwiftUI
import Testing

/// TEMPORARY: renders the push screens at 3x on a 393 x 852 pt frame into /tmp/gp-renders for design comparison.
@Suite
@MainActor
struct GuardianPushRenderTests {

    private let phone = GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")
    private let secondPhone = GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone")

    private func render(_ name: String, @ViewBuilder _ screen: () -> some View) {
        let theme = Auth0Theme()
        let view = VStack(spacing: 0) {
            Color.clear.frame(height: 62)
            LoginNavigationBar(title: "Log in")
            screen()
        }
        .frame(width: 393, height: 852)
        .background(theme.colors.background.layerBase)
        .auth0Theme(theme)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.cgImage else { Issue.record("no image for \(name)"); return }
        let url = URL(fileURLWithPath: "/tmp/gp-renders/\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    @Test func renderAll() {
        render("picker") {
            GuardianPushDevicePickerView(devices: [phone, secondPhone]) { _ in }
        }
        render("waiting-cooldown") {
            GuardianPushWaitingView(deviceName: phone.name, onResend: {}, onChooseAnotherDevice: {})
        }
        render("waiting-active") {
            GuardianPushWaitingView(deviceName: phone.name, isSending: false, resendCooldown: 0,
                                    onResend: {}, onChooseAnotherDevice: {})
        }
        render("outcome-other") {
            GuardianPushOutcomeView(failure: .other(message: nil), onSignInAgain: {})
        }
        render("outcome-network") {
            GuardianPushOutcomeView(failure: .network, onRetry: {})
        }
        render("approved") { GuardianPushApprovedView() }
    }
}
