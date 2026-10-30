import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Renders whatever step the controller is on. It never decides anything: the screens call the model's actions.
struct MfaHostView: View {
    @ObservedObject var controller: MfaController
    let configuration: MfaConfiguration

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .onChangeCompat(of: scenePhase) { phase in
                if phase == .active {
                    controller.appBecameActive()
                } else {
                    controller.appBecameInactive()
                }
            }
            .onChangeCompat(of: controller.step.identity) { _ in announceScreenChange() }
    }

    @ViewBuilder
    private var content: some View {
        if case .headless = configuration.presentation {
            EmptyView()
        } else {
            // A fresh view per step, so one screen's focus and scroll position never leak into the next.
            step
                .id(controller.step.identity)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var step: some View {
        let screens = configuration.screens
        let messages = configuration.messages
        switch controller.step {
        case let .loading(model):
            MfaLoadingScreen(model: model, messages: messages)
        case let .authenticatorList(model):
            screens.authenticatorList.view(for: model) { MfaAuthenticatorListScreen(model: model, messages: messages) }
        case let .factor(step):
            factorScreen(for: step)
        case let .error(model):
            screens.error.view(for: model) { MfaErrorScreen(model: model, messages: messages) }
        }
    }

    /// The app's replacement if it gave one, else the factor's own standard screen. The host knows no factor.
    @ViewBuilder
    private func factorScreen(for step: MfaFactorStep) -> some View {
        if let custom = configuration.screens.factorViews[step.factor]?(step.model) {
            custom
        } else if let standard = controller.standardView(for: step) {
            standard
        }
    }

    /// Moves VoiceOver to the new screen's title.
    private func announceScreenChange() {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        #endif
    }
}

extension MfaStep {
    /// Identifies the screen, ignoring what changes inside it, so a payload change updates in place and keeps focus.
    var identity: String {
        switch self {
        case .loading: return "loading"
        case let .authenticatorList(model): return "authenticatorList.\(model.header)"
        case let .factor(step): return "factor.\(step.factor)"
        case .error: return "error"
        }
    }
}
