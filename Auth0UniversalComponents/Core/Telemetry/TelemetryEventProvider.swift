/// A protocol for receiving telemetry events from the SDK.
///
/// Implement this protocol to receive client-side telemetry events and forward them
/// to your analytics backend (e.g., Mixpanel, Amplitude, custom).
///
/// ```swift
/// class MyAnalytics: TelemetryEventProvider {
///     func track(event: TelemetryEvent) {
///         mixpanel.track(event.name, properties: event.properties)
///     }
/// }
/// ```
public protocol TelemetryEventProvider: Sendable {
    /// Called when the SDK emits a telemetry event.
    ///
    /// - Parameter event: The telemetry event to track.
    func track(event: TelemetryEvent)
}
