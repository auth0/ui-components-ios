import Combine
import Foundation

/// Where Guardian push approval stands.
public enum GuardianPushApprovalState: Equatable, Sendable {
    /// Not started yet.
    case idle
    /// Several Guardian devices: the user picks one.
    case choosingDevice([GuardianPushDevice])
    /// The push is on its way to the device.
    case sending(GuardianPushDevice)
    /// Checking for approval. `canResend` is true while the server still offers this push.
    case waiting(GuardianPushDevice, canResend: Bool)
    /// The user approved; `onApproved` has been called.
    case approved
    /// Ended without approval. Only `.network` can be retried.
    case failed(GuardianPushFailure)
}

/// Sends the push and checks for approval until the user approves, denies, or it fails.
///
/// One request at a time: a new action first waits for the request already in flight, because
/// cancelling a task doesn't cancel its network call.
@MainActor
public final class GuardianPushApprovalController<Approval>: ObservableObject {

    /// What the screen shows. Render it with `GuardianPushView`.
    @Published public private(set) var state: GuardianPushApprovalState = .idle

    /// The Guardian devices on offer, in server order.
    public let devices: [GuardianPushDevice]

    /// True while the device list is shown.
    public var isChoosingDevice: Bool {
        if case .choosingDevice = state { return true }
        return false
    }

    /// True when going back to the device list can still lead to an approval.
    public var canChooseAnotherDevice: Bool {
        guard devices.count > 1 else { return false }
        switch state {
        case .sending, .waiting: return true
        case let .failed(failure): return failure.isRetryable
        case .idle, .choosingDevice, .approved: return false
        }
    }

    private var isApproved: Bool {
        if case .approved = state { return true }
        return false
    }

    private enum ResumePoint { case send, poll }

    private let client: AnyGuardianPushClient<Approval>
    private let policy: GuardianPushPollingPolicy
    private let sleep: (Int) async throws -> Void
    private let onApproved: (Approval) -> Void

    private var work: Task<Void, Never>?
    /// The wait between checks; ended early when the app comes back to the foreground.
    private var pause: Task<Void, Error>?
    private var device: GuardianPushDevice?
    private var interval: Int
    private var canResend = false
    private var resumePoint = ResumePoint.send
    private var isAppActive = true
    private var isSuspended = false

    /// - Parameters:
    ///   - client: Sends the push and checks for approval.
    ///   - devices: The Guardian devices on offer. Empty means push isn't available.
    ///   - policy: How often to check for approval.
    ///   - onApproved: Called once, on the main actor, when the user approves. An approval already on its way
    ///     when the work is cancelled is still reported, since the client may have acted on it.
    public convenience init<Client: GuardianPushClient>(client: Client,
                                                       devices: [GuardianPushDevice],
                                                       policy: GuardianPushPollingPolicy = .default,
                                                       onApproved: @escaping (Approval) -> Void)
    where Client.Approval == Approval {
        self.init(client: AnyGuardianPushClient(client), devices: devices, policy: policy,
                  sleep: GuardianPushPollingPolicy.sleep(milliseconds:),
                  onApproved: onApproved)
    }

    init(client: AnyGuardianPushClient<Approval>,
         devices: [GuardianPushDevice],
         policy: GuardianPushPollingPolicy,
         sleep: @escaping (Int) async throws -> Void,
         onApproved: @escaping (Approval) -> Void) {
        self.client = client
        self.devices = devices
        self.policy = policy
        self.sleep = sleep
        self.onApproved = onApproved
        self.interval = policy.defaultInterval
    }

    // MARK: Actions

    /// No device: push isn't available. One device: sends the push. Several: asks which.
    public func start() {
        guard case .idle = state else { return }
        switch devices.count {
        case 0: state = .failed(.unavailable)
        case 1: select(devices[0])
        default: state = .choosingDevice(devices)
        }
    }

    /// Sends the push to `device`, then checks for approval.
    public func select(_ device: GuardianPushDevice) {
        // Nothing more is sent once approved, and a second tap while sending is ignored.
        if isApproved { return }
        if case .sending = state { return }
        self.device = device
        state = .sending(device)
        run { [weak self] in await self?.send(to: device) }
    }

    /// Sends the push to the same device again.
    public func resend() {
        guard let device, canResend else { return }
        select(device)
    }

    /// After a retryable failure, picks up where it failed: sending, or checking.
    public func retry() {
        guard case let .failed(failure) = state, failure.isRetryable, let device else { return }
        switch resumePoint {
        case .send:
            select(device)
        case .poll:
            state = .waiting(device, canResend: canResend)
            run { [weak self] in await self?.poll() }
        }
    }

    /// Back to the device list, when `canChooseAnotherDevice`.
    public func chooseAnotherDevice() {
        guard canChooseAnotherDevice else { return }
        work?.cancel()
        state = .choosingDevice(devices)
    }

    /// Stops checking. A request already in flight still completes: an approval is still reported, anything else is ignored.
    public func cancel() {
        work?.cancel()
        isSuspended = false
    }

    /// Stops checking and waits for any request in flight. Call before the next step of the sign-in.
    public func stop() async {
        cancel()
        await work?.value
        work = nil
    }

    /// The screen went away: stop checking until `resume()`.
    public func suspend() {
        guard case .waiting = state else { return }
        work?.cancel()
        isSuspended = true
    }

    /// Picks up checking after `suspend()`.
    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        guard case .waiting = state else { return }
        run { [weak self] in await self?.poll() }
    }

    /// Approving in Guardian on the same phone sends this app to the background; coming back checks right away.
    public func setAppActive(_ isActive: Bool) {
        let cameBack = isActive && !isAppActive
        isAppActive = isActive
        if cameBack { pause?.cancel() }
    }

    // MARK: Work

    /// Runs `operation` after the previous one has fully finished.
    private func run(_ operation: @escaping () async -> Void) {
        let previous = work
        previous?.cancel()
        work = Task { [weak self] in
            await previous?.value
            // The previous work may have finished with an approval.
            guard !Task.isCancelled, self?.isApproved == false else { return }
            await operation()
        }
    }

    private func send(to device: GuardianPushDevice) async {
        do {
            let pending = try await client.sendPush(to: device)
            guard !Task.isCancelled else { return }
            interval = policy.initialInterval(pending)
            canResend = pending.canResend
            state = .waiting(device, canResend: canResend)
        } catch {
            guard !Task.isCancelled else { return }
            resumePoint = .send
            state = .failed(Self.failure(from: error))
            return
        }
        await poll()
    }

    private func poll() async {
        guard let device else { return }
        var networkFailures = 0
        while !Task.isCancelled {
            // Always wait first: checking sooner than the server asked is answered with slow down.
            do {
                try await wait(milliseconds: interval)
            } catch {
                return
            }
            let check: GuardianPushCheck<Approval>
            do {
                check = try await client.checkApproval()
            } catch {
                guard !Task.isCancelled else { return }
                let failure = Self.failure(from: error)
                if failure == .network {
                    // Failures while backgrounded (e.g. approving in Guardian) don't count.
                    if isAppActive { networkFailures += 1 }
                    if networkFailures <= policy.maxConsecutiveNetworkFailures { continue }
                    resumePoint = .poll
                }
                state = .failed(failure)
                return
            }
            // The client may already have acted on an approval (e.g. stored the credentials), so it's never dropped.
            if case let .approved(approval) = check {
                state = .approved
                onApproved(approval)
                return
            }
            // A late pending answer after Back or another action is dropped.
            guard !Task.isCancelled else { return }
            interval = policy.nextInterval(after: check, current: interval)
            switch check {
            case .approved:
                return
            case let .pending(pending), let .slowDown(pending):
                networkFailures = 0
                canResend = pending.canResend
                state = .waiting(device, canResend: canResend)
            }
        }
    }

    private func wait(milliseconds: Int) async throws {
        let sleep = self.sleep
        let pause = Task { try await sleep(milliseconds) }
        self.pause = pause
        defer { self.pause = nil }
        do {
            try await withTaskCancellationHandler {
                try await pause.value
            } onCancel: {
                pause.cancel()
            }
        } catch is CancellationError {
            // Woken early by `setAppActive(true)`, unless this work itself was cancelled.
        }
        // A wait can end normally just as the work is cancelled (e.g. Back); never check after that.
        try Task.checkCancellation()
    }

    private static func failure(from error: Error) -> GuardianPushFailure {
        if let failure = error as? GuardianPushFailure { return failure }
        return .other(message: (error as? LocalizedError)?.errorDescription)
    }
}
