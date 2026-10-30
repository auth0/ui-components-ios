@testable import Auth0UniversalComponents
import Combine
import SwiftUI
import Testing

#if canImport(UIKit)
import UIKit

/// The host view forwards the app going to the background and coming back to the factors' sessions, which is what makes
/// a push approved in another app get noticed at once. That has to hold when the app draws every screen itself.
@Suite
@MainActor
struct MfaHostViewLifecycleTests {

    private final class Phase: ObservableObject {
        @Published var value: ScenePhase = .active
    }

    private struct Driver: View {
        @ObservedObject var phase: Phase
        let controller: MfaController
        let configuration: MfaConfiguration

        var body: some View {
            MfaHostView(controller: controller, configuration: configuration)
                .environment(\.scenePhase, phase.value)
        }
    }

    private func settle() async {
        for _ in 0..<6 { try? await Task.sleep(nanoseconds: 40_000_000) }
    }

    private func logOfSession(presentation: MfaPresentation) async -> [String] {
        let alpha = ScriptedFactor(.alpha)
        let controller = MfaController(initialOffers: [scriptedOffer("alpha:0", factor: .alpha)],
                                       registry: MfaFactorRegistry([alpha]), committer: FakeCommitter(),
                                       onFinish: { _ in })
        if case let .headless(stream) = presentation { controller.publish(to: stream) }
        controller.start()
        let phase = Phase()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let configuration = MfaConfiguration(presentation: presentation)
        window.rootViewController = UIHostingController(
            rootView: Driver(phase: phase, controller: controller, configuration: configuration))
        window.makeKeyAndVisible()
        await settle()
        phase.value = .inactive
        await settle()
        phase.value = .active
        await settle()
        window.isHidden = true
        return alpha.last.log
    }

    @Test func standardScreens_forwardTheAppGoingAwayAndComingBack() async {
        let log = await logOfSession(presentation: .standard)
        #expect(log.contains("inactive") && log.contains("active"), "\(log)")
    }

    @Test func headless_forwardsTheAppGoingAwayAndComingBack_justTheSame() async {
        let log = await logOfSession(presentation: .headless(MfaStepStream()))
        #expect(log.contains("inactive") && log.contains("active"), "\(log)")
    }
}
#endif
