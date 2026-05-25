import Foundation

/// A telemetry event emitted by the SDK for client-side analytics.
///
/// SDK consumers receive these events through their ``TelemetryEventProvider`` implementation
/// and can forward them to any analytics backend (Mixpanel, Amplitude, custom, etc.).
///
/// Events are categorized by type: screen views, flows, API calls, and errors.
/// All events include a timestamp and optional duration/status for API calls.
public struct TelemetryEvent: Sendable {
    /// The category of this telemetry event.
    public let category: EventCategory
    /// The event name (e.g., "totp_push_qr", "enrollment_started", "start_totp_enrollment").
    public let name: String
    /// Additional properties associated with the event.
    public let properties: [String: String]
    /// When the event occurred.
    public let timestamp: Date
    /// Duration in milliseconds (for API call events).
    public let durationMs: Int?
    /// The outcome status (for API call and flow events).
    public let status: EventStatus?

    /// Categories of telemetry events emitted by the SDK.
    public enum EventCategory: String, Sendable {
        case screenView = "screen_view"
        case flow = "flow"
        case apiCall = "api_call"
        case error = "error"
    }

    /// The outcome of an API call or flow event.
    public enum EventStatus: String, Sendable {
        case success
        case failure
    }

    public init(category: EventCategory,
                name: String,
                properties: [String: String] = [:],
                timestamp: Date = Date(),
                durationMs: Int? = nil,
                status: EventStatus? = nil) {
        self.category = category
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.status = status
    }
}
