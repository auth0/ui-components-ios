@testable import Auth0UniversalComponents
import Foundation

/// Scripted `GuardianPushClient`: each call pops the next queued result and is recorded.
@MainActor
final class ScriptedGuardianPushClient {
    private(set) var sent: [GuardianPushDevice] = []
    private(set) var checks = 0

    var sendResults: [Result<GuardianPushPending, Error>] = []
    var checkResults: [Result<GuardianPushCheck<String>, Error>] = []
    /// Runs inside `checkApproval()` before it returns, to hold a check in flight.
    var onCheck: (() async -> Void)?
    /// Runs inside `sendPush(to:)` before it returns, to hold a send in flight.
    var onSend: (() async -> Void)?

    var erased: AnyGuardianPushClient<String> {
        AnyGuardianPushClient(sendPush: { [unowned self] device in
            sent.append(device)
            let result = sendResults.isEmpty
                ? .success(GuardianPushPending(retryAfter: 2_000))
                : sendResults.removeFirst()
            await onSend?()
            return try result.get()
        }, checkApproval: { [unowned self] in
            checks += 1
            let result = checkResults.isEmpty ? .success(.pending(GuardianPushPending())) : checkResults.removeFirst()
            await onCheck?()
            return try result.get()
        })
    }
}

/// Records each wait; optionally suspends until cancelled, like a long `Task.sleep`.
@MainActor
final class RecordingSleeper {
    private(set) var delays: [Int] = []
    var suspends = false

    func sleep(_ milliseconds: Int) async throws {
        delays.append(milliseconds)
        if suspends { try await Task.sleep(nanoseconds: .max) }
    }
}

/// Collects what `onApproved` reports.
final class Approvals {
    var values: [String] = []
}

/// What the controller suites share: a scripted client and sleeper, plus helpers to build and settle a controller.
@MainActor
protocol GuardianPushControllerSuite {
    var client: ScriptedGuardianPushClient { get }
    var sleeper: RecordingSleeper { get }
}

extension GuardianPushControllerSuite {
    var phone: GuardianPushDevice { GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone") }
    var tablet: GuardianPushDevice { GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone") }

    func makeSUT(devices: [GuardianPushDevice]? = nil,
                 approvals: Approvals = Approvals()) -> GuardianPushApprovalController<String> {
        GuardianPushApprovalController(client: client.erased, devices: devices ?? [phone], policy: .default,
                                       sleep: sleeper.sleep, onApproved: { approvals.values.append($0) })
    }

    func settle(_ sut: GuardianPushApprovalController<String>) async {
        await sut.stop()
    }

    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }
}
