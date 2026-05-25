/// Configuration for SDK telemetry behavior.
///
/// Controls whether HTTP header telemetry and client-side event tracking are enabled,
/// and optionally provides a custom event provider to receive events.
///
/// ```swift
/// // Default: telemetry enabled, no custom provider
/// Auth0UniversalComponentsSDKInitializer.initialize(tokenProvider: myProvider)
///
/// // Disable all telemetry
/// Auth0UniversalComponentsSDKInitializer.initialize(
///     tokenProvider: myProvider,
///     telemetryConfiguration: .disabled
/// )
///
/// // Custom event provider
/// Auth0UniversalComponentsSDKInitializer.initialize(
///     tokenProvider: myProvider,
///     telemetryConfiguration: TelemetryConfiguration(provider: MyAnalytics())
/// )
/// ```
public struct TelemetryConfiguration: Sendable {
    /// Whether telemetry is enabled. When `false`, no HTTP headers are sent
    /// and no client-side events are dispatched.
    public let enabled: Bool
    /// Optional provider to receive client-side telemetry events.
    public let provider: (any TelemetryEventProvider)?

    /// Telemetry enabled with no custom event provider (default).
    public static let enabled = TelemetryConfiguration(enabled: true, provider: nil)
    /// All telemetry disabled.
    public static let disabled = TelemetryConfiguration(enabled: false, provider: nil)

    /// Creates a telemetry configuration.
    ///
    /// - Parameters:
    ///   - enabled: Whether telemetry is enabled (defaults to `true`).
    ///   - provider: Optional provider to receive client-side events.
    public init(enabled: Bool = true, provider: (any TelemetryEventProvider)? = nil) {
        self.enabled = enabled
        self.provider = provider
    }
}
