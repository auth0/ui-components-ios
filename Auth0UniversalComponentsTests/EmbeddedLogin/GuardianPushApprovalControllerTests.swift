@testable import Auth0UniversalComponents
import Foundation
import Testing

/// Scripted `GuardianPushClient`: each call pops the next queued result and is recorded.
@MainActor
final class ScriptedGuardianPushClient {
    private(set) var sent: [GuardianPushDevice] = []
    private(set) var checks = 0

    var sendResults: [Result<GuardianPushPending, Error>] = []
    var checkResults: [Result<GuardianPushCheck<String>, Error>] = []
    /// Runs inside `checkApproval()` before it returns, to hold a check in flight.
    var onCheck: (() async -> Void)?

    var erased: AnyGuardianPushClient<String> {
        AnyGuardianPushClient(sendPush: { [unowned self] device in
            sent.append(device)
            return try (sendResults.isEmpty ? .success(GuardianPushPending(retryAfter: 2_000)) : sendResults.removeFirst()).get()
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

@Suite
@MainActor
struct GuardianPushApprovalControllerTests {

    private let phone = GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")
    private let tablet = GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone")
    private let client = ScriptedGuardianPushClient()
    private let sleeper = RecordingSleeper()

    private final class Approvals {
        var values: [String] = []
    }

    private func makeSUT(devices: [GuardianPushDevice]? = nil,
                         approvals: Approvals = Approvals()) -> GuardianPushApprovalController<String> {
        GuardianPushApprovalController(client: client.erased, devices: devices ?? [phone], policy: .default,
                                       sleep: sleeper.sleep, onApproved: { approvals.values.append($0) })
    }

    private func settle(_ sut: GuardianPushApprovalController<String>) async {
        await sut.stop()
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    // MARK: Starting

    @Test func noDevice_isUnavailable() {
        let sut = makeSUT(devices: [])
        sut.start()
        #expect(sut.state == .failed(.unavailable))
        #expect(client.sent.isEmpty)
    }

    @Test func oneDevice_sendsAtOnce() async {
        client.checkResults = [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.start()
        await eventually { sut.state == .approved }
        #expect(client.sent == [phone])
    }

    @Test func severalDevices_askWhichOne() {
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        #expect(sut.state == .choosingDevice([phone, tablet]))
        #expect(client.sent.isEmpty)
    }

    @Test func doubleTapOnADevice_sendsOnePush() async {
        client.checkResults = [.success(.approved("creds"))]
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()

        sut.select(tablet)
        sut.select(tablet)
        await eventually { sut.state == .approved }

        #expect(client.sent == [tablet])
    }

    @Test func start_isIgnoredOnceRunning() async {
        client.checkResults = [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.start()
        sut.start()
        await eventually { sut.state == .approved }
        #expect(client.sent.count == 1)
    }

    // MARK: Waiting and approval

    @Test func pendingThenApproved_reportsTheApprovalOnce() async {
        let approvals = Approvals()
        client.sendResults = [.success(GuardianPushPending(retryAfter: 2_000, canResend: true))]
        client.checkResults = [.success(.pending(GuardianPushPending(retryAfter: 3_000))), .success(.approved("creds"))]
        let sut = makeSUT(approvals: approvals)

        sut.select(phone)
        await eventually { sut.state == .approved }

        #expect(approvals.values == ["creds"])
        #expect(sleeper.delays == [2_000, 3_000])
    }

    @Test func waiting_showsWhetherResendIsOffered() async {
        sleeper.suspends = true
        client.sendResults = [.success(GuardianPushPending(retryAfter: 2_000, canResend: true))]
        let sut = makeSUT()

        sut.select(phone)
        await eventually { sut.state == .waiting(phone, canResend: true) }

        #expect(sut.state == .waiting(phone, canResend: true))
        await settle(sut)
    }

    @Test func slowDown_usesTheServerInterval_orDoubles() async {
        client.checkResults = [.success(.slowDown(GuardianPushPending(retryAfter: 5_000))),
                               .success(.slowDown(GuardianPushPending())),
                               .success(.approved("creds"))]
        let sut = makeSUT()

        sut.select(phone)
        await eventually { sut.state == .approved }

        #expect(sleeper.delays == [2_000, 5_000, 10_000])
    }

    @Test func intervals_areClamped() async {
        client.sendResults = [.success(GuardianPushPending(retryAfter: 10))]
        client.checkResults = [.success(.pending(GuardianPushPending(retryAfter: 999_999))), .success(.approved("creds"))]
        let sut = makeSUT()

        sut.select(phone)
        await eventually { sut.state == .approved }

        #expect(sleeper.delays == [1_000, 60_000])
    }

    // MARK: Failures

    @Test func sendFailure_isShown() async {
        client.sendResults = [.failure(GuardianPushFailure.sessionEnded)]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { sut.state == .failed(.sessionEnded) }
        #expect(sut.state == .failed(.sessionEnded))
    }

    @Test(arguments: [GuardianPushFailure.denied, .expired, .sessionEnded, .other(message: "Nope")])
    func terminalCheck_endsWaiting(_ failure: GuardianPushFailure) async {
        client.checkResults = [.failure(failure)]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { sut.state == .failed(failure) }
        #expect(sut.state == .failed(failure))
        #expect(!failure.isRetryable)
    }

    @Test func networkFailures_areRetriedThreeTimes() async {
        client.checkResults = Array(repeating: .failure(GuardianPushFailure.network), count: 4)
        let sut = makeSUT()

        sut.select(phone)
        await eventually { sut.state == .failed(.network) }

        #expect(client.checks == 4)
    }

    @Test func backgroundNetworkFailures_dontCount() async {
        client.checkResults = Array(repeating: .failure(GuardianPushFailure.network), count: 5) + [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.setAppActive(false)

        sut.select(phone)
        await eventually { sut.state == .approved }

        #expect(sut.state == .approved)
    }

    @Test func retry_afterNetworkFailure_keepsChecking() async {
        client.checkResults = Array(repeating: .failure(GuardianPushFailure.network), count: 4) + [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { sut.state == .failed(.network) }

        sut.retry()
        await eventually { sut.state == .approved }

        #expect(client.sent.count == 1)
    }

    @Test func retry_afterSendNetworkFailure_sendsAgain() async {
        client.sendResults = [.failure(GuardianPushFailure.network)]
        client.checkResults = [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { sut.state == .failed(.network) }

        sut.retry()
        await eventually { sut.state == .approved }

        #expect(client.sent == [phone, phone])
    }

    @Test func nonGuardianError_isOther() async {
        struct Opaque: LocalizedError { var errorDescription: String? { "Keychain unavailable" } }
        client.checkResults = [.failure(Opaque())]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { if case .failed = sut.state { return true } else { return false } }
        #expect(sut.state == .failed(.other(message: "Keychain unavailable")))
    }

    // MARK: Resend, cancel and lifecycle

    @Test func resend_sendsAgainOnlyWhenOffered() async {
        sleeper.suspends = true
        client.sendResults = [.success(GuardianPushPending(retryAfter: 2_000, canResend: false))]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { sut.state == .waiting(phone, canResend: false) }

        sut.resend()
        for _ in 0..<100 { await Task.yield() }

        #expect(client.sent.count == 1)
        await settle(sut)
    }

    @Test func cancelWhileWaiting_makesNoCheck() async {
        sleeper.suspends = true
        let sut = makeSUT()
        sut.select(phone)
        await eventually { !sleeper.delays.isEmpty }

        await sut.stop()

        #expect(client.checks == 0)
    }

    /// The client may already have acted on the approval (Embedded Login stores the credentials), so it's kept.
    @Test func cancelDuringCheck_stillDeliversALateApproval() async {
        let approvals = Approvals()
        var inFlight: CheckedContinuation<Void, Never>?
        client.onCheck = { await withCheckedContinuation { inFlight = $0 } }
        client.checkResults = [.success(.approved("late"))]
        let sut = makeSUT(approvals: approvals)
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.cancel()
        inFlight?.resume()
        await sut.stop()

        #expect(approvals.values == ["late"])
        #expect(sut.state == .approved)
    }

    @Test func cancelDuringCheck_dropsALatePendingAnswer() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onCheck = { await withCheckedContinuation { inFlight = $0 } }
        client.checkResults = [.success(.pending(GuardianPushPending(canResend: true)))]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.cancel()
        inFlight?.resume()
        await sut.stop()

        #expect(sut.state == .waiting(phone, canResend: false))
    }

    @Test func lateApproval_skipsAQueuedSend() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onCheck = { await withCheckedContinuation { inFlight = $0 } }
        client.checkResults = [.success(.approved("late"))]
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.chooseAnotherDevice()
        sut.select(tablet)
        inFlight?.resume()
        await eventually { sut.state == .approved }
        for _ in 0..<100 { await Task.yield() }

        #expect(sut.state == .approved)
        #expect(client.sent == [phone])
    }

    @Test func select_isIgnoredOnceApproved() async {
        client.checkResults = [.success(.approved("creds"))]
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        sut.select(phone)
        await eventually { sut.state == .approved }

        sut.select(tablet)
        for _ in 0..<100 { await Task.yield() }

        #expect(sut.state == .approved)
        #expect(client.sent == [phone])
    }

    @Test func returningToTheApp_checksRightAway() async {
        sleeper.suspends = true
        client.checkResults = [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.setAppActive(false)
        sut.select(phone)
        await eventually { !sleeper.delays.isEmpty }

        sut.setAppActive(true)
        await eventually { sut.state == .approved }

        #expect(client.checks == 1)
    }

    @Test func suspendAndResume_restartsChecking() async {
        sleeper.suspends = true
        let sut = makeSUT()
        sut.select(phone)
        await eventually { sleeper.delays.count == 1 }

        sut.suspend()
        sut.resume()
        await eventually { sleeper.delays.count == 2 }

        #expect(sleeper.delays.count == 2)
        await settle(sut)
    }

    @Test(arguments: [GuardianPushFailure.denied, .expired, .sessionEnded, .other(message: nil)])
    func chooseAnotherDevice_isIgnoredAfterATerminalFailure(_ failure: GuardianPushFailure) async {
        client.checkResults = [.failure(failure)]
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        sut.select(phone)
        await eventually { sut.state == .failed(failure) }

        #expect(!sut.canChooseAnotherDevice)
        sut.chooseAnotherDevice()

        #expect(sut.state == .failed(failure))
    }

    @Test func chooseAnotherDevice_isAllowedAfterANetworkFailure() async {
        client.checkResults = Array(repeating: .failure(GuardianPushFailure.network), count: 4)
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        sut.select(phone)
        await eventually { sut.state == .failed(.network) }

        #expect(sut.canChooseAnotherDevice)
        sut.chooseAnotherDevice()

        #expect(sut.state == .choosingDevice([phone, tablet]))
    }

    @Test func chooseAnotherDevice_needsSeveralDevices() async {
        sleeper.suspends = true
        let sut = makeSUT()
        sut.select(phone)
        await eventually { if case .waiting = sut.state { return true } else { return false } }

        #expect(!sut.canChooseAnotherDevice)
        sut.chooseAnotherDevice()

        #expect(sut.state == .waiting(phone, canResend: false))
        await settle(sut)
    }

    @Test func chooseAnotherDevice_returnsToTheList() async {
        sleeper.suspends = true
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        sut.select(tablet)
        await eventually { if case .waiting = sut.state { return true } else { return false } }

        sut.chooseAnotherDevice()

        #expect(sut.state == .choosingDevice([phone, tablet]))
        #expect(sut.isChoosingDevice)
        await settle(sut)
    }
}
