import Testing
import Foundation
@testable import Auth0UniversalComponents

@Suite(.serialized)
struct TelemetryManagerTests {

    // MARK: - Configuration Tests

    @Test("TelemetryManager dispatches events when enabled with provider")
    func testDispatchesWhenEnabled() {
        let provider = MockTelemetryEventProvider()
        let config = TelemetryConfiguration(enabled: true, provider: provider)
        let manager = TelemetryManager(configuration: config)

        manager.trackScreenView("test_screen")

        #expect(provider.events.count == 1)
        #expect(provider.events.first?.name == "test_screen")
        #expect(provider.events.first?.category == .screenView)
    }

    @Test("TelemetryManager suppresses events when disabled")
    func testSuppressesWhenDisabled() {
        let provider = MockTelemetryEventProvider()
        let config = TelemetryConfiguration(enabled: false, provider: provider)
        let manager = TelemetryManager(configuration: config)

        manager.trackScreenView("test_screen")
        manager.trackFlow("enrollment_started", factorType: "totp")
        manager.trackApiCall("start_totp_enrollment", durationMs: 100, status: .success)
        manager.trackError("my_account_api_error", errorType: "MyAccountError", scope: "openid")

        #expect(provider.events.isEmpty)
    }

    @Test("TelemetryManager does not crash when enabled without provider")
    func testNoProviderNoCrash() {
        let config = TelemetryConfiguration(enabled: true, provider: nil)
        let manager = TelemetryManager(configuration: config)

        manager.trackScreenView("test_screen")
        manager.trackFlow("enrollment_started", factorType: "totp")
        manager.trackApiCall("start_totp_enrollment", durationMs: 100, status: .success)
        manager.trackError("unknown_error", errorType: "NSError", scope: "openid")
        // Test passes if no crash
    }

    // MARK: - Screen View Events

    @Test("trackScreenView emits correct event")
    func testTrackScreenView() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackScreenView("my_account_auth_methods")

        let event = provider.events.first
        #expect(event?.category == .screenView)
        #expect(event?.name == "my_account_auth_methods")
        #expect(event?.properties.isEmpty == true)
        #expect(event?.durationMs == nil)
        #expect(event?.status == nil)
    }

    @Test("trackScreenView includes properties")
    func testTrackScreenViewWithProperties() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackScreenView("totp_push_qr", properties: ["factor_type": "totp"])

        let event = provider.events.first
        #expect(event?.properties["factor_type"] == "totp")
    }

    // MARK: - Flow Events

    @Test("trackFlow emits correct event with factor type")
    func testTrackFlow() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackFlow("enrollment_started", factorType: "sms")

        let event = provider.events.first
        #expect(event?.category == .flow)
        #expect(event?.name == "enrollment_started")
        #expect(event?.properties["factor_type"] == "sms")
        #expect(event?.status == nil)
    }

    @Test("trackFlow includes status when provided")
    func testTrackFlowWithStatus() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackFlow("enrollment_completed", factorType: "totp", status: .success)

        let event = provider.events.first
        #expect(event?.status == .success)
        #expect(event?.properties["status"] == "success")
        #expect(event?.properties["factor_type"] == "totp")
    }

    @Test("trackFlow emits failure status")
    func testTrackFlowFailure() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackFlow("enrollment_failed", factorType: "email", status: .failure)

        let event = provider.events.first
        #expect(event?.status == .failure)
        #expect(event?.properties["status"] == "failure")
    }

    // MARK: - API Call Events

    @Test("trackApiCall emits correct success event")
    func testTrackApiCallSuccess() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackApiCall("start_totp_enrollment", durationMs: 342, status: .success)

        let event = provider.events.first
        #expect(event?.category == .apiCall)
        #expect(event?.name == "start_totp_enrollment")
        #expect(event?.durationMs == 342)
        #expect(event?.status == .success)
        #expect(event?.properties["duration_ms"] == "342")
        #expect(event?.properties["status"] == "success")
        #expect(event?.properties["error_type"] == nil)
    }

    @Test("trackApiCall emits correct failure event with error type")
    func testTrackApiCallFailure() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackApiCall("confirm_email_enrollment", durationMs: 1200, status: .failure, errorType: "MyAccountError")

        let event = provider.events.first
        #expect(event?.category == .apiCall)
        #expect(event?.name == "confirm_email_enrollment")
        #expect(event?.durationMs == 1200)
        #expect(event?.status == .failure)
        #expect(event?.properties["error_type"] == "MyAccountError")
    }

    // MARK: - Error Events

    @Test("trackError emits correct event")
    func testTrackError() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        manager.trackError("my_account_api_error", errorType: "MyAccountError", scope: "openid create:me:authentication_methods")

        let event = provider.events.first
        #expect(event?.category == .error)
        #expect(event?.name == "my_account_api_error")
        #expect(event?.properties["error_type"] == "MyAccountError")
        #expect(event?.properties["scope"] == "openid create:me:authentication_methods")
    }

    // MARK: - Timestamp

    @Test("Events include timestamp close to current time")
    func testTimestamp() {
        let provider = MockTelemetryEventProvider()
        let manager = TelemetryManager(configuration: TelemetryConfiguration(provider: provider))

        let before = Date()
        manager.trackScreenView("test")
        let after = Date()

        let timestamp = provider.events.first!.timestamp
        #expect(timestamp >= before)
        #expect(timestamp <= after)
    }

    // MARK: - Shared Instance

    @Test("TelemetryManager.shared can be replaced")
    func testSharedReplacement() {
        let provider = MockTelemetryEventProvider()
        let config = TelemetryConfiguration(enabled: true, provider: provider)
        TelemetryManager.shared = TelemetryManager(configuration: config)

        TelemetryManager.shared.trackScreenView("shared_test")

        #expect(provider.events.count == 1)
        #expect(provider.events.first?.name == "shared_test")

        // Reset to default
        TelemetryManager.shared = TelemetryManager(configuration: .enabled)
    }
}
