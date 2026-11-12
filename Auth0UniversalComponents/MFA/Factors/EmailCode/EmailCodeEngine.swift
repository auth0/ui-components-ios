import Foundation

// The seam between the email code factor and the code engine under `PhoneCode/`.
//
// The engine (state machine, session, send ledger, transport contract) never looks at how a code travels: it sends one,
// checks what the user types, and counts the resend wait. Its names say "phone" only because texting a code came first,
// so the email factor runs on it as it is, under its own names. This is the one file in this folder that names it
// (`ArchitectureTests` holds the rest to that); if the engine is ever renamed, only the right-hand sides change.

typealias EmailCodeTransport = PhoneCodeTransport
typealias EmailCodeSent = PhoneCodeSent
typealias EmailCodeVerification = PhoneCodeVerification
typealias EmailCodePolicy = PhoneCodePolicy
typealias EmailCodeSendLedger = PhoneCodeSendLedger

/// Runs one emailed code from "send it" to "verified". The engine does the work; this only gives the screen a model
/// that speaks of an address.
@MainActor
final class EmailCodeSession: MfaFactorSession {
    private let engine: PhoneCodeSession

    init(offer: MfaFactorOffer, transport: EmailCodeTransport, policy: EmailCodePolicy, clock: MfaClock,
         host: MfaFactorHost, ledger: EmailCodeSendLedger? = nil) {
        // `delivery` only labels the engine's own model, which `model` replaces. It never reaches the server.
        engine = PhoneCodeSession(offer: offer, delivery: .text, transport: transport, policy: policy, clock: clock,
                                  host: host, ledger: ledger)
    }

    var model: (any MfaFactorModel)? {
        (engine.model as? PhoneCodeChallengeModel).map(EmailCodeChallengeModel.init)
    }

    func start() { engine.start() }
    func deactivate() { engine.deactivate() }
    func cancelAndWait() async { await engine.cancelAndWait() }
    func appBecameActive() { engine.appBecameActive() }
    func appBecameInactive() { engine.appBecameInactive() }
}

private extension EmailCodeChallengeModel {
    /// The engine's model, with the address in place of the phone number. Every action is the engine's own.
    init(_ engine: PhoneCodeChallengeModel) {
        self.init(address: engine.destination, codeLength: engine.codeLength, isVerifying: engine.isVerifying,
                  isCodeRejected: engine.isCodeRejected, isCodeExpired: engine.isCodeExpired,
                  requestError: engine.requestError, canResend: engine.canResend,
                  resendAvailableIn: engine.resendAvailableIn, canSwitch: engine.canSwitch,
                  submit: engine.submit, resend: engine.resend, switchFactor: engine.switchFactor,
                  cancel: engine.cancel)
    }
}
