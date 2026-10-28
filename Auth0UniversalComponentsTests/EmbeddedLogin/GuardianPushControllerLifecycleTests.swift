@testable import Auth0UniversalComponents
import Combine
import Foundation
import Testing

/// Resend, cancel, leaving the screen, choosing another device and publishing.
@Suite
@MainActor
struct GuardianPushControllerLifecycleTests: GuardianPushControllerSuite {

    let client = ScriptedGuardianPushClient()
    let sleeper = RecordingSleeper()

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

    /// The screen went away during "Sending request": the push still goes out, but nothing checks for it.
    @Test func suspendWhileSending_doesNotCheckUntilResumed() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onSend = { await withCheckedContinuation { inFlight = $0 } }
        let sut = makeSUT()
        sut.select(phone)
        await eventually { inFlight != nil }

        sut.suspend()
        inFlight?.resume()
        await eventually { if case .waiting = sut.state { return true } else { return false } }
        for _ in 0..<100 { await Task.yield() }
        #expect(client.checks == 0)
        #expect(client.sent == [phone])

        client.checkResults = [.success(.approved("creds"))]
        sut.resume()
        await eventually { sut.state == .approved }
        #expect(client.checks == 1)
        #expect(client.sent == [phone])
    }

    @Test func suspendWhileSending_releasesTheControllerOnceSent() async {
        var inFlight: CheckedContinuation<Void, Never>?
        client.onSend = { await withCheckedContinuation { inFlight = $0 } }
        weak var weakSUT: GuardianPushApprovalController<String>?
        do {
            let sut = makeSUT()
            weakSUT = sut
            sut.select(phone)
            await eventually { inFlight != nil }
            sut.suspend()
        }
        inFlight?.resume()
        await eventually { weakSUT == nil }

        #expect(weakSUT == nil)
        #expect(client.checks == 0)
    }

    @Test func unchangedPendingAnswers_doNotRepublish() async {
        final class Changes { var count = 0; var bag: AnyCancellable? }
        let changes = Changes()
        client.checkResults = Array(repeating: .success(.pending(GuardianPushPending())), count: 5)
            + [.success(.approved("creds"))]
        let sut = makeSUT()
        sut.select(phone)
        await eventually { if case .waiting = sut.state { return true } else { return false } }
        changes.bag = sut.objectWillChange.sink { changes.count += 1 }

        await eventually { sut.state == .approved }

        // Only the switch to `.approved`, not one per identical "pending".
        #expect(changes.count == 1)
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
