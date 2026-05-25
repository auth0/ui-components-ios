import Testing
import Foundation
@testable import Auth0UniversalComponents

@Suite
struct TelemetryConfigurationTests {

    @Test("Default configuration is enabled with no provider")
    func testDefaultEnabled() {
        let config = TelemetryConfiguration.enabled
        #expect(config.enabled == true)
        #expect(config.provider == nil)
    }

    @Test("Disabled configuration has enabled=false")
    func testDisabled() {
        let config = TelemetryConfiguration.disabled
        #expect(config.enabled == false)
        #expect(config.provider == nil)
    }

    @Test("Custom init with provider")
    func testCustomInit() {
        let provider = MockTelemetryEventProvider()
        let config = TelemetryConfiguration(enabled: true, provider: provider)
        #expect(config.enabled == true)
        #expect(config.provider != nil)
    }

    @Test("Custom init defaults enabled to true")
    func testDefaultEnabledParam() {
        let config = TelemetryConfiguration()
        #expect(config.enabled == true)
        #expect(config.provider == nil)
    }

    @Test("Custom init with disabled and provider still has provider")
    func testDisabledWithProvider() {
        let provider = MockTelemetryEventProvider()
        let config = TelemetryConfiguration(enabled: false, provider: provider)
        #expect(config.enabled == false)
        #expect(config.provider != nil)
    }
}
