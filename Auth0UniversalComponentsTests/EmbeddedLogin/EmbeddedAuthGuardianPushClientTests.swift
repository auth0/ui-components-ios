@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct EmbeddedAuthGuardianPushClientTests {

    private typealias F = EmbeddedAuthFixtures

    private let stub = StubEmbeddedAuthClient()
    private let device = GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")

    private var sut: EmbeddedAuthGuardianPushClient { EmbeddedAuthGuardianPushClient(client: stub) }

    // MARK: Devices

    @Test func devices_keepServerOrder_andIgnoreOtherFactors() {
        let next = F.needs([F.verifyTOTP, F.challengePush,
                            ["action": "action:challenge:push:v1", "index": 1, "name": "Sudhanshu's iPhone"]])
        guard case let .insufficientAuthorization(_, actions) = next.reason else { Issue.record(); return }
        #expect(EmbeddedAuthGuardianPushClient.devices(in: actions) == [
            GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone"),
            GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone"),
        ])
    }

    // MARK: Sending

    @Test func sendPush_returnsTheServerInterval() async throws {
        stub.challengePushResults = [F.needs([F.verifyOob(pollInMs: 3_000)])]

        let pending = try await sut.sendPush(to: device)

        #expect(stub.calls == [.challengePush(index: 0)])
        #expect(pending == GuardianPushPending(retryAfter: 3_000, canResend: false))
    }

    @Test func sendPush_reportsResendWhenThePushIsStillOffered() async throws {
        stub.challengePushResults = [F.needs([F.verifyOob(), F.challengePush])]
        #expect(try await sut.sendPush(to: device).canResend)
    }

    @Test func sendPush_withoutAnApprovalStep_isAFailure() async {
        stub.challengePushResults = [F.needs([F.verifyTOTP])]
        await #expect(throws: GuardianPushFailure.other(message: nil)) { try await sut.sendPush(to: device) }
    }

    @Test func sendPush_offline_isRetryable() async {
        stub.challengePushResults = [F.network]
        await #expect(throws: GuardianPushFailure.network) { try await sut.sendPush(to: device) }
    }

    // MARK: Checking

    @Test func approval_returnsTheCredentials() async throws {
        stub.verifyOobResults = [.success(Credentials(accessToken: "push"))]
        guard case let .approved(credentials) = try await sut.checkApproval() else { Issue.record(); return }
        #expect(credentials.accessToken == "push")
    }

    @Test func pending_carriesTheNextInterval() async throws {
        stub.verifyOobResults = [.failure(F.needs([F.verifyOob(pollInMs: 4_000)], subReason: "authorization_pending"))]
        #expect(try await sut.checkApproval() == .pending(GuardianPushPending(retryAfter: 4_000)))
    }

    @Test func slowDown_isReported() async throws {
        stub.verifyOobResults = [.failure(F.needs([F.verifyOob(pollInMs: 8_000)], subReason: "slow_down"))]
        #expect(try await sut.checkApproval() == .slowDown(GuardianPushPending(retryAfter: 8_000)))
    }

    @Test func terminalErrors_mapToPushFailures() async {
        let cases: [(EmbeddedAuthError, GuardianPushFailure)] = [
            (F.terminal("access_denied", description: "authorization_rejected"), .denied),
            (F.terminal("access_denied", description: "challenge_expired"), .expired),
            (F.terminal("access_denied", description: "no_eligible_factors"), .unavailable),
            (F.terminal("invalid_grant", description: "Session expired."), .sessionEnded),
            (F.noActiveSession, .sessionEnded),
            (F.network, .network),
        ]
        for (error, failure) in cases {
            stub.verifyOobResults = [.failure(error)]
            await #expect(throws: failure) { try await sut.checkApproval() }
        }
    }

    @Test func otherDenial_keepsTheServerMessage() async {
        stub.verifyOobResults = [.failure(F.terminal("access_denied", description: "Blocked by policy"))]
        await #expect(throws: GuardianPushFailure.other(message: "Blocked by policy")) { try await sut.checkApproval() }
    }
}
