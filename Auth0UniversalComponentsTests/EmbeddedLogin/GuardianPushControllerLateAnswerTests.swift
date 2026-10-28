@testable import Auth0UniversalComponents
import Foundation
import Testing

/// Answers that arrive after Back, suspend or choosing another device.
@Suite
@MainActor
struct GuardianPushControllerLateAnswerTests: GuardianPushControllerSuite {

    let client = ScriptedGuardianPushClient()
    let sleeper = RecordingSleeper()

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

    /// The SDK has already cleared its session, so the denial is shown rather than a later "session ended".
    @Test func lateDenial_afterChoosingAnotherDevice_isShown() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onCheck = { await withCheckedContinuation { inFlight = $0 } }
        client.checkResults = [.failure(GuardianPushFailure.denied)]
        let sut = makeSUT(devices: [phone, tablet])
        sut.start()
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.chooseAnotherDevice()
        sut.select(tablet)
        inFlight?.resume()
        await eventually { sut.state == .failed(.denied) }
        for _ in 0..<100 { await Task.yield() }

        #expect(sut.state == .failed(.denied))
        #expect(client.sent == [phone])
    }

    @Test func lateExpiry_afterSuspend_isShownOnResume() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onCheck = { await withCheckedContinuation { inFlight = $0 } }
        client.checkResults = [.failure(GuardianPushFailure.expired)]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.suspend()
        inFlight?.resume()
        await eventually { sut.state == .failed(.expired) }
        sut.resume()

        #expect(sut.state == .failed(.expired))
        #expect(client.checks == 1)
    }

    @Test func lateNetworkFailure_afterCancel_isStillDropped() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onCheck = { await withCheckedContinuation { inFlight = $0 } }
        client.checkResults = [.failure(GuardianPushFailure.network)]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.cancel()
        inFlight?.resume()
        await sut.stop()

        #expect(sut.state == .waiting(phone, canResend: false))
    }
}
