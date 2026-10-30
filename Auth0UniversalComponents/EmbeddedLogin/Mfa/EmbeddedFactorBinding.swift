import Auth0
import Foundation

/// Embedded Login's side of a factor: how to read the factor's offers out of the server's menu, which steps to
/// advertise to `authorize`, and how to build the factor over this sign-in. The factor itself knows none of this.
/// Supporting a new factor here means adding one binding to `EmbeddedMfaStep`.
@MainActor
protocol EmbeddedFactorBinding {
    /// The `authorize` steps this factor needs the server to route to.
    var capabilities: [EmbeddedCapability] { get }
    func offers(in nextActions: [NextAction]) -> [MfaFactorOffer]
    func makeFactor(_ services: EmbeddedFactorServices) -> any MfaFactor
}

/// What a binding is given to build its factor over one sign-in.
@MainActor
struct EmbeddedFactorServices {
    let client: EmbeddedAuthClient
    let stager: EmbeddedMfaStager
    /// Reads a whole menu, every factor included. Needed after an approval, when the server asks for another factor.
    let menu: ([NextAction]) -> [MfaFactorOffer]
}

/// Holds verified credentials until the Core says the sign-in is still live, then stores them.
@MainActor
final class EmbeddedMfaStager: MfaCommitter {
    private let store: CredentialsStoring
    private var staged: Credentials?
    private var isAbandoned = false

    init(store: CredentialsStoring) {
        self.store = store
    }

    /// Called by a transport when the server accepts the sign-in. Throws if the flow already ended.
    func stage(_ credentials: Credentials) throws {
        // Approved after the flow ended: nothing may be stored on this device.
        guard !isAbandoned else { throw MfaError.cancelled }
        staged = credentials
    }

    func commit() throws {
        guard let credentials = staged else { throw MfaError.unexpected(nil) }
        staged = nil
        do {
            try store.store(credentials: credentials)
        } catch {
            throw MfaError.credentialsNotSaved
        }
    }

    func abandon() {
        isAbandoned = true
        staged = nil
    }
}

/// Auth0's errors in the Core's vocabulary.
enum EmbeddedMfaErrors {
    /// A failure that ended the flow. IP blocks and consent get their own wording through `unexpected`.
    static func map(_ error: EmbeddedAuthError) -> MfaError {
        switch error.reason {
        case .network: return .network
        case .authorizationRejected: return .rejected
        case .challengeExpired: return .tokenExpired
        case .sessionExpired, .noActiveSession: return .tokenInvalid
        case .noEligibleFactors: return .noEligibleFactors
        case .tooManyWrongOtpAttempts, .tooManyAttempts, .tooManyLogins: return .tooManyAttempts
        case .insufficientAuthorization, .accessDenied, .consentRequired, .invalidRequest, .ipBlocked, .unknown:
            return .unexpected(error.displayMessage)
        @unknown default:
            return .unexpected(error.displayMessage)
        }
    }
}
