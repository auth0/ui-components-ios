import Auth0
import Combine
import SwiftUI

/// Plugs the MFA Core into Embedded Login's additional step. This is the only place that knows both sides: it reads the
/// server's menu with each factor's binding, builds the factors over this sign-in, runs the Core, and reports back to
/// the login in the login's own words.
///
/// To support another factor, add its binding to `bindings`. Neither the login nor the Core changes.
@MainActor
final class EmbeddedMfaStep: ObservableObject, AdditionalStepProviding {
    /// The app's current settings. Read when a flow starts, so a later change reaches the next sign-in.
    var configuration: MfaConfiguration
    private let clock: MfaClock
    private let bindings: [EmbeddedFactorBinding]
    /// The app's `onMfaError`, if it set one. Told how a flow ended without signing in (a cancel isn't one: the user is
    /// still in the login).
    var errorHandler: ((MfaError) -> Void)?

    /// - Parameter bindings: The factors this login can run. Defaults to the ones that ship.
    init(configuration: MfaConfiguration = MfaConfiguration(), clock: MfaClock = SystemMfaClock(),
         bindings: [EmbeddedFactorBinding]? = nil) {
        self.configuration = configuration
        self.clock = clock
        self.bindings = bindings ?? [EmbeddedPushBinding()]
    }

    /// What to advertise to `authorize` so the server only routes to factors that are plugged in.
    var capabilities: [EmbeddedCapability] {
        var seen: [EmbeddedCapability] = []
        for capability in bindings.flatMap(\.capabilities) where !seen.contains(capability) { seen.append(capability) }
        return seen
    }

    func makeSession(context: AdditionalStepContext, delegate: AdditionalStepDelegate) -> AdditionalStepSession {
        let stager = EmbeddedMfaStager(store: context.credentialsStore)
        let menu: ([NextAction]) -> [MfaFactorOffer] = { [bindings] next in bindings.flatMap { $0.offers(in: next) } }
        let services = EmbeddedFactorServices(client: context.client, stager: stager, menu: menu)
        let session = EmbeddedMfaSession(
            offers: menu(context.nextActions), registry: MfaFactorRegistry(bindings.map { $0.makeFactor(services) }),
            stager: stager, configuration: configuration, clock: clock, delegate: delegate,
            errorHandler: { [weak self] in self?.errorHandler })
        return session
    }
}

/// One running MFA flow, seen from the login.
@MainActor
final class EmbeddedMfaSession: AdditionalStepSession {
    let controller: MfaController
    private let configuration: MfaConfiguration
    private weak var delegate: AdditionalStepDelegate?

    init(offers: [MfaFactorOffer], registry: MfaFactorRegistry, stager: EmbeddedMfaStager,
         configuration: MfaConfiguration, clock: MfaClock, delegate: AdditionalStepDelegate,
         errorHandler: @escaping () -> ((MfaError) -> Void)?) {
        self.configuration = configuration
        self.delegate = delegate
        var finish: ((MfaError?) -> Void)?
        controller = MfaController(
            initialOffers: offers, registry: registry, committer: stager, messages: configuration.messages,
            clock: clock,
            exit: .startOver, maximumRounds: configuration.maximumRounds, onFinish: { finish?($0) },
            onLeave: { [weak delegate] in delegate?.additionalStepRequestedRestart() })
        if case let .headless(stream) = configuration.presentation { controller.publish(to: stream) }
        finish = { [weak delegate] error in
            guard let error else { delegate?.additionalStepDidFinish(.completed); return }
            switch error {
            case .cancelled:
                delegate?.additionalStepDidFinish(.cancelled)
            case .noEligibleFactors:
                let handler = errorHandler()
                handler?(error)
                delegate?.additionalStepDidFinish(.unavailable(reported: handler != nil))
            default:
                errorHandler()?(error)
                delegate?.additionalStepDidFinish(.failed)
            }
        }
    }

    var view: AnyView { AnyView(MfaHostView(controller: controller, configuration: configuration)) }
    var isFinished: Bool { controller.isFinished }
    func start() { controller.start() }
    func cancel() {
        controller.send(.cancel)
        controller.detach()
    }

    func cancelAndWait() async {
        controller.detach()
        await controller.cancelAndWait()
    }
}
