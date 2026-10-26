import SwiftUI

/// `GuardianPushView` driven by a `GuardianPushApprovalController`: starts it, pauses it while off screen,
/// and checks right away when the app returns to the foreground.
public struct GuardianPushApprovalView<Approval>: View {
    @ObservedObject private var controller: GuardianPushApprovalController<Approval>
    private let onSignInAgain: (() -> Void)?

    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter onSignInAgain: Starts a new sign-in after a terminal outcome. `nil` hides the button.
    public init(controller: GuardianPushApprovalController<Approval>, onSignInAgain: (() -> Void)? = nil) {
        self.controller = controller
        self.onSignInAgain = onSignInAgain
    }

    public var body: some View {
        GuardianPushView(state: controller.state, actions: GuardianPushActions(
            selectDevice: { controller.select($0) },
            resend: { controller.resend() },
            retry: { controller.retry() },
            chooseAnotherDevice: controller.devices.count > 1 ? { controller.chooseAnotherDevice() } : nil,
            signInAgain: onSignInAgain
        ))
        .onAppear {
            controller.start()
            controller.resume()
        }
        .onDisappear { controller.suspend() }
        .onChange(of: scenePhase) { phase in
            controller.setAppActive(phase == .active)
        }
    }
}
