import Foundation

/// Internal singleton responsible for dispatching telemetry events.
///
/// Initialized during SDK setup with the user's ``TelemetryConfiguration``.
/// All telemetry calls are fire-and-forget — failures never impact SDK functionality.
final class TelemetryManager: @unchecked Sendable {
    static var shared = TelemetryManager(configuration: .enabled)

    let enabled: Bool
    private let provider: (any TelemetryEventProvider)?

    init(configuration: TelemetryConfiguration) {
        self.enabled = configuration.enabled
        self.provider = configuration.provider
    }

    func track(_ event: TelemetryEvent) {
        guard enabled, let provider else { return }
        provider.track(event: event)
    }

    // MARK: - Convenience Methods

    func trackScreenView(_ screen: String, properties: [String: String] = [:]) {
        track(TelemetryEvent(
            category: .screenView,
            name: screen,
            properties: properties
        ))
    }

    func trackFlow(_ name: String, factorType: String, status: TelemetryEvent.EventStatus? = nil) {
        var properties = ["factor_type": factorType]
        if let status {
            properties["status"] = status.rawValue
        }
        track(TelemetryEvent(
            category: .flow,
            name: name,
            properties: properties,
            status: status
        ))
    }

    func trackApiCall(_ name: String, durationMs: Int, status: TelemetryEvent.EventStatus, errorType: String? = nil) {
        var properties = [
            "duration_ms": String(durationMs),
            "status": status.rawValue
        ]
        if let errorType {
            properties["error_type"] = errorType
        }
        track(TelemetryEvent(
            category: .apiCall,
            name: name,
            properties: properties,
            durationMs: durationMs,
            status: status
        ))
    }

    func trackError(_ name: String, errorType: String, scope: String) {
        track(TelemetryEvent(
            category: .error,
            name: name,
            properties: [
                "error_type": errorType,
                "scope": scope
            ]
        ))
    }
}
