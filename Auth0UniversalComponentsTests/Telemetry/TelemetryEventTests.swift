import Testing
import Foundation
@testable import Auth0UniversalComponents

@Suite
struct TelemetryEventTests {

    @Test("TelemetryEvent initializes with all parameters")
    func testFullInit() {
        let date = Date()
        let event = TelemetryEvent(
            category: .apiCall,
            name: "start_totp_enrollment",
            properties: ["duration_ms": "200", "status": "success"],
            timestamp: date,
            durationMs: 200,
            status: .success
        )

        #expect(event.category == .apiCall)
        #expect(event.name == "start_totp_enrollment")
        #expect(event.properties["duration_ms"] == "200")
        #expect(event.properties["status"] == "success")
        #expect(event.timestamp == date)
        #expect(event.durationMs == 200)
        #expect(event.status == .success)
    }

    @Test("TelemetryEvent initializes with defaults")
    func testDefaultInit() {
        let before = Date()
        let event = TelemetryEvent(category: .screenView, name: "test_screen")
        let after = Date()

        #expect(event.category == .screenView)
        #expect(event.name == "test_screen")
        #expect(event.properties.isEmpty)
        #expect(event.timestamp >= before)
        #expect(event.timestamp <= after)
        #expect(event.durationMs == nil)
        #expect(event.status == nil)
    }

    @Test("EventCategory raw values are correct")
    func testCategoryRawValues() {
        #expect(TelemetryEvent.EventCategory.screenView.rawValue == "screen_view")
        #expect(TelemetryEvent.EventCategory.flow.rawValue == "flow")
        #expect(TelemetryEvent.EventCategory.apiCall.rawValue == "api_call")
        #expect(TelemetryEvent.EventCategory.error.rawValue == "error")
    }

    @Test("EventStatus raw values are correct")
    func testStatusRawValues() {
        #expect(TelemetryEvent.EventStatus.success.rawValue == "success")
        #expect(TelemetryEvent.EventStatus.failure.rawValue == "failure")
    }
}
