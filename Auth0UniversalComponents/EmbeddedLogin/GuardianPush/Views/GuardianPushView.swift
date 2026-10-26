import SwiftUI

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
