import Foundation

/// The factors a flow can run. A new factor is added here by whoever assembles the flow; the Core isn't edited.
@MainActor
struct MfaFactorRegistry {
    private let byID: [MfaFactorID: any MfaFactor]

    init(_ factors: [any MfaFactor]) {
        byID = Dictionary(factors.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    var ids: Set<MfaFactorID> { Set(byID.keys) }

    func factor(for id: MfaFactorID) -> (any MfaFactor)? { byID[id] }

    /// Supported offers only, in rank order; the server's order breaks ties.
    func eligible(_ offers: [MfaFactorOffer]) -> [MfaFactorOffer] {
        offers.enumerated()
            .compactMap { index, offer in byID[offer.factor].map { (rank: $0.rank, index: index, offer: offer) } }
            .sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }
            .map(\.offer)
    }
}
