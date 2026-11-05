@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// An `EmbeddedAuthClient` whose calls can be held on the wire, and that records how many were in flight at once.
/// `verifyOob` waits until the test lets it go; `challengePush` answers at once, as the server does when a push goes
/// out.
@MainActor
final class GatedEmbeddedAuthClient: EmbeddedAuthClient {
    private typealias Fix = EmbeddedAuthFixtures

    enum Call: Equatable {
        case verifyOob
        case challengePush(index: Int)
    }

    private(set) var calls: [Call] = []
    private(set) var maxConcurrent = 0
    private var inFlight = 0
    private var held: [CheckedContinuation<Error, Never>] = []

    /// While true, every `verifyOob` waits to be released.
    var holdsVerifyOob = true
    /// Keeps each call in flight a little longer, so two calls that overlap are seen overlapping.
    var lingers = false

    /// How many checks are waiting to be released.
    var heldCount: Int { held.count }

    /// Lets the oldest held check go, answering with `answer` (still pending, unless the test says otherwise).
    func releaseNext(with answer: Error? = nil) {
        let pending = Fix.needs([Fix.verifyOob()], subReason: "authorization_pending")
        held.removeFirst().resume(returning: answer ?? pending)
    }

    func waitUntilCalled(_ call: Call) async {
        await eventually { calls.contains(call) }
    }

    func challengePush(index: Int) async throws {
        begin(.challengePush(index: index))
        defer { inFlight -= 1 }
        await linger()
        // The push went out: the server asks to check for approval next, and still offers the push.
        throw Fix.needs([Fix.verifyOob(), Fix.challengePush])
    }

    func verifyOob() async throws -> Credentials {
        begin(.verifyOob)
        defer { inFlight -= 1 }
        if holdsVerifyOob {
            throw await withCheckedContinuation { (continuation: CheckedContinuation<Error, Never>) in
                held.append(continuation)
            }
        }
        await linger()
        throw Fix.needs([Fix.verifyOob()], subReason: "authorization_pending")
    }

    // The login's own steps aren't part of the push loop.
    func authorize(connection: String) async throws { throw Fix.noActiveSession }
    func identify(_ identifier: String, type: IdentifierType) async throws { throw Fix.noActiveSession }
    func challengeEmail(index: Int) async throws { throw Fix.noActiveSession }
    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws { throw Fix.noActiveSession }
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials { throw Fix.noActiveSession }

    private func begin(_ call: Call) {
        calls.append(call)
        inFlight += 1
        maxConcurrent = max(maxConcurrent, inFlight)
    }

    private func linger() async {
        if lingers { try? await Task.sleep(nanoseconds: 2_000_000) }
    }
}

/// `EmbeddedPushTransport` is shared by every push session of a sign-in, and the SDK allows one request at a time.
/// `PushSession` only serializes inside one session, so these tests cover the hand-off between sessions.
@Suite
@MainActor
struct EmbeddedPushTransportSerializationTests {

    private let client = GatedEmbeddedAuthClient()
    private let offerA = MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)
    private let offerB = MfaFactorOffer(id: "push:1", factor: .push, label: "iPad", reference: 1)

    private func transport() -> EmbeddedPushTransport {
        EmbeddedPushTransport(client: client, stager: EmbeddedMfaStager(delivery: StubCredentialsDelivery()),
                              menu: { _ in [] })
    }

    /// Device A has a check on the wire when the user switches to device B: B's push must wait for it.
    @Test func aSecondSessionsPush_waitsForTheFirstSessionsCheck() async throws {
        let sut = transport()
        let check = Task { try await sut.checkApproval() }
        await client.waitUntilCalled(.verifyOob)
        let send = Task { try await sut.sendPush(to: offerB) }
        await settle()
        #expect(client.calls == [.verifyOob], "B's push has not gone out while A's check is on the wire")

        client.releaseNext()
        let checked = try await check.value
        let sent = try await send.value

        #expect(isPending(checked))
        #expect(sent.canResend)
        #expect(client.calls == [.verifyOob, .challengePush(index: 1)])
        #expect(client.maxConcurrent == 1)
    }

    /// The first request fails: the next one must still get its turn, not wait forever.
    @Test func aFirstCallThatThrows_stillHandsTheTurnOn() async throws {
        let sut = transport()
        let check = Task { try await sut.checkApproval() }
        await client.waitUntilCalled(.verifyOob)
        let send = Task { try await sut.sendPush(to: offerB) }
        await settle()

        client.releaseNext(with: EmbeddedAuthFixtures.network)
        let outcome = await check.result
        let sent = try await send.value

        guard case let .failure(error) = outcome else { Issue.record("the check should have failed"); return }
        #expect(error as? MfaError == .network)
        #expect(sent.canResend, "B's push still went out")
        #expect(client.calls == [.verifyOob, .challengePush(index: 1)])
        #expect(client.maxConcurrent == 1)
    }

    /// Requests that arrive while one is on the wire run in the order they arrived.
    @Test func waitingRequests_runInTheOrderTheyArrived() async throws {
        let sut = transport()
        let first = Task { try await sut.checkApproval() }
        await client.waitUntilCalled(.verifyOob)
        client.holdsVerifyOob = false                       // later checks answer at once

        let sendB = Task { try await sut.sendPush(to: offerB) }
        await settle()
        let secondCheck = Task { try await sut.checkApproval() }
        await settle()
        let sendA = Task { try await sut.sendPush(to: offerA) }
        await settle()
        #expect(client.calls == [.verifyOob], "all three are waiting behind the first check")

        client.releaseNext()
        _ = try await first.value
        _ = try await sendB.value
        _ = try await secondCheck.value
        _ = try await sendA.value

        #expect(client.calls == [.verifyOob, .challengePush(index: 1), .verifyOob, .challengePush(index: 0)])
        #expect(client.maxConcurrent == 1)
    }

    /// A burst of mixed requests, each kept in flight a moment, never overlaps.
    @Test func aBurstOfRequests_neverRunsMoreThanOneAtATime() async throws {
        client.holdsVerifyOob = false
        client.lingers = true
        let sut = transport()
        var tasks: [Task<Void, Error>] = []
        for index in 0..<12 {
            tasks.append(Task {
                if index.isMultiple(of: 2) {
                    _ = try await sut.checkApproval()
                } else {
                    _ = try await sut.sendPush(to: index.isMultiple(of: 3) ? offerA : offerB)
                }
            })
        }
        for task in tasks { try await task.value }

        #expect(client.calls.count == 12)
        #expect(client.maxConcurrent == 1)
    }

    private func isPending(_ check: PushCheck) -> Bool {
        if case .pending = check { return true } else { return false }
    }
}
