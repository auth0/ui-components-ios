import SwiftUI

/// What the Guardian push screens can ask for. A `nil` closure hides its button.
public struct GuardianPushActions {
    /// A device was picked from the list.
    public var selectDevice: (GuardianPushDevice) -> Void
    /// Sends the push again; shown only when the state allows it.
    public var resend: (() -> Void)?
    /// Retries after a retryable failure (`.network`).
    public var retry: (() -> Void)?
    /// Back to the device list.
    public var chooseAnotherDevice: (() -> Void)?
    /// Terminal outcomes: start a new sign-in.
    public var signInAgain: (() -> Void)?

    public init(selectDevice: @escaping (GuardianPushDevice) -> Void,
                resend: (() -> Void)? = nil,
                retry: (() -> Void)? = nil,
                chooseAnotherDevice: (() -> Void)? = nil,
                signInAgain: (() -> Void)? = nil) {
        self.selectDevice = selectDevice
        self.resend = resend
        self.retry = retry
        self.chooseAnotherDevice = chooseAnotherDevice
        self.signInAgain = signInAgain
    }
}

/// Renders a `GuardianPushApprovalState`. Plain state in, closures out, so it works with any driver.
public struct GuardianPushView: View {
    let state: GuardianPushApprovalState
    let actions: GuardianPushActions

    public init(state: GuardianPushApprovalState, actions: GuardianPushActions) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
        switch state {
        case .idle:
            GuardianPushWaitingView(deviceName: "your device", isSending: true)
        case let .choosingDevice(devices):
            GuardianPushDevicePickerView(devices: devices, onSelect: actions.selectDevice)
        case let .sending(device):
            GuardianPushWaitingView(deviceName: device.name, isSending: true)
        case let .waiting(device, canResend):
            GuardianPushWaitingView(deviceName: device.name,
                                    onResend: canResend ? actions.resend : nil,
                                    onChooseAnotherDevice: actions.chooseAnotherDevice)
        case .approved:
            GuardianPushApprovedView()
        case let .failed(failure):
            GuardianPushOutcomeView(failure: failure, onRetry: actions.retry, onSignInAgain: actions.signInAgain)
        }
    }
}

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

// MARK: - Previews

private let sampleDevice = GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")

#Preview("Waiting") {
    GuardianPushView(state: .waiting(sampleDevice, canResend: true),
                     actions: GuardianPushActions(selectDevice: { _ in }, resend: {}, chooseAnotherDevice: {}))
}

#Preview("Choose a device") {
    GuardianPushView(state: .choosingDevice([sampleDevice, GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone")]),
                     actions: GuardianPushActions(selectDevice: { _ in }))
}

#Preview("Unavailable") {
    GuardianPushView(state: .failed(.unavailable), actions: GuardianPushActions(selectDevice: { _ in }, signInAgain: {}))
}

#Preview("Denied") {
    GuardianPushView(state: .failed(.denied), actions: GuardianPushActions(selectDevice: { _ in }, signInAgain: {}))
}

#Preview("No connection") {
    GuardianPushView(state: .failed(.network), actions: GuardianPushActions(selectDevice: { _ in }, retry: {}))
}

#Preview("Approved") {
    GuardianPushView(state: .approved, actions: GuardianPushActions(selectDevice: { _ in }))
}
