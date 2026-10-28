@testable import Auth0UniversalComponents
import Foundation
import Testing

/// Starting, waiting, approval, intervals and failures.
@Suite
@MainActor
struct GuardianPushApprovalControllerTests: GuardianPushControllerSuite {

    let client = ScriptedGuardianPushClient()
    let sleeper = RecordingSleeper()

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

    /// Each slow down waits at least 2 s longer, whatever interval the server repeats.
    @Test func slowDown_waitsAtLeastTwoSecondsLonger() async {
        client.checkResults = [.success(.slowDown(GuardianPushPending(retryAfter: 9_000))),
                               .success(.slowDown(GuardianPushPending())),
                               .success(.slowDown(GuardianPushPending(retryAfter: 2_000))),
                               .success(.approved("creds"))]
        let sut = makeSUT()

        sut.select(phone)
        await eventually { sut.state == .approved }

        // The server's longer interval, then +2 s with none given, then +2 s although it asks for less.
        #expect(sleeper.delays == [2_000, 9_000, 11_000, 13_000])
    }

    @Test func slowDown_withTheSameInterval_stillSlowsDown() {
        let next = GuardianPushPollingPolicy.default.nextInterval(
            after: GuardianPushCheck<String>.slowDown(GuardianPushPending(retryAfter: 2_000)), current: 2_000)
        #expect(next == 4_000)
    }

    @Test func intervals_areClamped() async {
        client.sendResults = [.success(GuardianPushPending(retryAfter: 10))]
        client.checkResults = [.success(.pending(GuardianPushPending(retryAfter: 999_999))),
                               .success(.approved("creds"))]
        let sut = makeSUT()

        sut.select(phone)
        await eventually { sut.state == .approved }

        #expect(sleeper.delays == [1_000, 60_000])
    }

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
        client.checkResults = Array(repeating: .failure(GuardianPushFailure.network), count: 5)
            + [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.setAppActive(false)

        sut.select(phone)
        await eventually { sut.state == .approved }

        #expect(sut.state == .approved)
    }

    @Test func retry_afterNetworkFailure_keepsChecking() async {
        client.checkResults = Array(repeating: .failure(GuardianPushFailure.network), count: 4)
            + [.success(.approved("creds"))]
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
}
