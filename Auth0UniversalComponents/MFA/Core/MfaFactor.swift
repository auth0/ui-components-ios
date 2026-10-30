import SwiftUI

// The contract between the MFA Core and a factor. The Core only ever talks to a factor through these types, so a new
// factor is a new conformance and the Core stays as it is.

/// Names a kind of factor. An open set: each factor declares its own id, and the Core never switches over them.
public struct MfaFactorID: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The identifier as text.
    public let rawValue: String

    /// Creates an identifier.
    ///
    /// - Parameter rawValue: A name that is unique among factors, such as `"push"`.
    public init(_ rawValue: String) { self.rawValue = rawValue }
    /// Creates an identifier from a string literal.
    public init(stringLiteral value: String) { rawValue = value }
    /// The identifier as text.
    public var description: String { rawValue }
}

/// One row in the factor list: a phone number, an email address, a push device.
public struct MfaFactorOffer: Equatable, Identifiable, Sendable {
    /// Stable and unique within a menu, e.g. `push:0`.
    public let id: String
    /// The kind of factor this is.
    public let factor: MfaFactorID
    /// As the server masked it (`••• 9239`), or a device name (`iPhone`).
    public let label: String?
    /// The adapter's own reference for this offer, handed back unchanged. It isn't a position in a list.
    let reference: Int?
    /// Anything else the factor and its adapter agree on (for example a delivery method).
    let info: [String: String]

    init(id: String, factor: MfaFactorID, label: String?, reference: Int? = nil, info: [String: String] = [:]) {
        self.id = id
        self.factor = factor
        self.label = label
        self.reference = reference
        self.info = info
    }
}

/// What a factor's screen renders. Each factor defines its own model; the Core carries it without looking inside.
public protocol MfaFactorModel {
    func isEqual(to other: any MfaFactorModel) -> Bool
}

extension MfaFactorModel where Self: Equatable {
    /// Returns whether `other` is the same kind of model with equal values.
    ///
    /// - Parameter other: The model to compare with.
    public func isEqual(to other: any MfaFactorModel) -> Bool { (other as? Self) == self }
}

/// How a factor appears in the factor list.
struct MfaFactorRowContent: Equatable {
    let title: String
    let subtitle: String?
    /// An image name in `ResourceBundle.default`.
    let icon: String?
}

/// What the Core gives a session when it starts it.
struct MfaFactorEnvironment {
    let clock: MfaClock
}

/// A factor plugs into the Core as this: its identity and order, how it looks in the list, and a session that runs it.
@MainActor
protocol MfaFactor {
    var id: MfaFactorID { get }
    /// Lower is shown first (phishing-resistance order).
    var rank: Int { get }
    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent
    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession
    /// The standard screen for one of this factor's models. `nil` if the model isn't this factor's.
    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView?
}

/// Everything inside one factor: its own state, timers and requests. The Core never looks inside.
@MainActor
protocol MfaFactorSession: AnyObject {
    /// What to show now. `nil` while the factor is still preparing (for example sending a challenge).
    var model: (any MfaFactorModel)? { get }
    func start()
    /// The user moved to another factor: stop timers and don't start new requests. A request already on its way may
    /// still report, and a verified answer still signs the user in.
    func deactivate()
    /// The flow is over: stop everything and wait for the request in flight, which the server allows one at a time.
    func cancelAndWait() async
    func appBecameActive()
    func appBecameInactive()
}

/// What a session can tell the Core.
@MainActor
protocol MfaFactorHost: AnyObject {
    /// "Verify another way" is only useful when there is somewhere to go.
    var canSwitch: Bool { get }
    /// `model` changed, so the screen must be redrawn.
    func modelDidChange()
    /// Verified: the credentials are staged. The Core decides whether the flow is still live and stores them.
    func completed()
    /// Verified, and the policy asks for another factor.
    func needsAnotherFactor(_ offers: [MfaFactorOffer])
    func failed(_ error: MfaError)
    func switchFactor()
    func cancel()
}
