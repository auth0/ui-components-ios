@testable import Auth0UniversalComponents
import SwiftUI
import Testing

// A second, completely different factor, written the way a future one would be, using only the contract the Core
// publishes. If adding it needed an edit to the Core, these tests could not compile. It lives in the tests only.

/// A factor that asks for a typed code. Its model, copy, screen and server calls are all its own.
struct CodeModel: MfaFactorModel, Equatable {
    let maskedTarget: String
    let inputRejected: Bool
    let submit: MfaAction<String>
    let switchFactor: MfaAction<Void>
    let cancel: MfaAction<Void>
}

extension MfaFactorID {
    static let code: MfaFactorID = "code"
}

struct CodeMessages: MfaFactorMessages {
    var title = "Enter your code"
    static let key = "codeChallenge"
    static var defaults: CodeMessages { CodeMessages() }
}

extension MfaMessages {
    var codeChallenge: CodeMessages {
        get { self[CodeMessages.self] }
        set { self[CodeMessages.self] = newValue }
    }
}

struct CodeScreen: View {
    let model: CodeModel
    let title: String
    var body: some View { Text("\(title) \(model.maskedTarget)") }
}

/// What the code factor needs from a server.
@MainActor
protocol CodeTransport {
    func verify(code: String) async throws -> Bool
}

@MainActor
final class ScriptedCodeTransport: CodeTransport {
    var accepted: Set<String> = ["123456"]
    private(set) var attempts: [String] = []
    func verify(code: String) async throws -> Bool {
        attempts.append(code)
        return accepted.contains(code)
    }
}

@MainActor
struct CodeFactor: MfaFactor {
    let id = MfaFactorID.code
    let rank = 10
    let transport: CodeTransport

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        MfaFactorRowContent(title: "Code to \(offer.label ?? "you")", subtitle: nil, icon: nil)
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        CodeSession(offer: offer, transport: transport, host: host)
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? CodeModel).map { AnyView(CodeScreen(model: $0, title: messages.codeChallenge.title)) }
    }
}

@MainActor
final class CodeSession: MfaFactorSession {
    private let offer: MfaFactorOffer
    private let transport: CodeTransport
    private weak var host: MfaFactorHost?
    private var rejected = false
    private var inFlight: Task<Void, Never>?

    init(offer: MfaFactorOffer, transport: CodeTransport, host: MfaFactorHost) {
        self.offer = offer
        self.transport = transport
        self.host = host
    }

    var model: (any MfaFactorModel)? {
        CodeModel(maskedTarget: offer.label ?? "", inputRejected: rejected,
                  submit: MfaAction<String> { [weak self] in self?.submit($0) },
                  switchFactor: MfaAction<Void> { [weak self] in self?.host?.switchFactor() },
                  cancel: MfaAction<Void> { [weak self] in self?.host?.cancel() })
    }

    func start() { host?.modelDidChange() }
    func deactivate() {}
    func appBecameActive() {}
    func appBecameInactive() {}
    func cancelAndWait() async { await inFlight?.value }

    private func submit(_ code: String) {
        inFlight = Task { [weak self] in
            guard let self else { return }
            do {
                if try await transport.verify(code: code) {
                    host?.completed()
                } else {
                    rejected = true
                    host?.modelDidChange()
                }
            } catch {
                host?.failed(.from(error))
            }
        }
    }
}

@Suite
@MainActor
struct AddingAFactorTests {

    private let push = ScriptedFactor(.push, rank: 20)
    private let codes = ScriptedCodeTransport()
    private let committer = FakeCommitter()
    private let finish = FinishLog()
    private let phone = MfaFactorOffer(id: "code:0", factor: .code, label: "••• 9239")
    private let device = scriptedOffer("push:0", factor: .push, label: "iPhone")

    private func controller() -> MfaController {
        MfaController(initialOffers: [device, phone], registry: MfaFactorRegistry([push, CodeFactor(transport: codes)]),
                      committer: committer, onFinish: { [finish] in finish.record($0) })
    }

    private func list(_ sut: MfaController) -> AuthenticatorListModel? {
        if case let .authenticatorList(model) = sut.step { return model }
        return nil
    }

    private func codeModel(_ sut: MfaController) -> CodeModel? {
        if case let .factor(step) = sut.step { return step.model as? CodeModel }
        return nil
    }

    @Test func theNewFactor_appearsInTheList_wordedByItself_inItsRankPosition() {
        let sut = controller()
        sut.start()
        #expect(list(sut)?.rows.map(\.title) == ["Code to ••• 9239", "iPhone"])
        #expect(list(sut)?.rows.map(\.factor) == [.code, .push])
    }

    @Test func theNewFactor_runsToSignIn_throughTheUnchangedCore() async {
        let sut = controller()
        sut.start()
        list(sut)?.select("code:0")
        #expect(codeModel(sut)?.inputRejected == false)

        codeModel(sut)?.submit("000000")
        await settle()
        #expect(codeModel(sut)?.inputRejected == true, "a wrong code keeps the user on the screen")

        codeModel(sut)?.submit("123456")
        await settle()
        #expect(codes.attempts == ["000000", "123456"])
        #expect(committer.stored == 1)
        #expect(finish.results == [nil])
    }

    @Test func switchingBetweenTheOldAndNewFactor_works() {
        let sut = controller()
        sut.start()
        list(sut)?.select("push:0")
        push.last.becomeReady()
        if case let .factor(step) = sut.step, let model = step.model as? ScriptedModel { model.switchFactor() }
        list(sut)?.select("code:0")
        #expect(codeModel(sut) != nil)
        #expect(push.last.log.contains("deactivate"))
    }

    @Test func theNewFactorsCopy_andScreen_plugInThroughTheSameOpenSlots() {
        let messages = MfaMessages.default.with { $0.codeChallenge.title = "Type it in" }
        #expect(messages.codeChallenge.title == "Type it in")
        #expect(MfaMessages.default.codeChallenge.title == "Enter your code")

        let screens = MfaScreens().replacing(.code) { (model: CodeModel) in Text(model.maskedTarget) }
        #expect(screens.factorViews[.code] != nil)

        let sut = controller()
        sut.start()
        list(sut)?.select("code:0")
        guard case let .factor(step) = sut.step else { Issue.record("expected the factor's screen"); return }
        #expect(sut.standardView(for: step) != nil, "the Core renders it through the factor's own standardView")
    }

    @Test func stepsFromTheNewFactor_haveTheirOwnIdentity() {
        let sut = controller()
        sut.start()
        list(sut)?.select("code:0")
        #expect(sut.step.identity == "factor.code")
    }
}
