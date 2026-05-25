import Testing
import Foundation
@testable import Auth0UniversalComponents
@testable import Auth0

@Suite(.serialized)
struct MyAccountClientFactoryTests {

    private let mockDomain = "test-tenant.auth0.com"
    private let mockToken = "mock_access_token"

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test("Factory creates client with telemetry when enabled")
    func testCreatesClientWithTelemetryEnabled() {
        let provider = MockTelemetryEventProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: TelemetryConfiguration(enabled: true, provider: provider),
            tokenProvider: MockTokenProvider()
        )

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: makeMockSession()
        )

        // The client should have telemetry enabled (non-nil value)
        #expect(client.telemetry.value != nil)
    }

    @Test("Factory creates client with telemetry disabled")
    func testCreatesClientWithTelemetryDisabled() {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: .disabled,
            tokenProvider: MockTokenProvider()
        )

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: makeMockSession()
        )

        // When disabled, telemetry value should be nil
        #expect(client.telemetry.value == nil)
    }

    @Test("Factory overload without session works")
    func testCreatesClientWithoutSession() {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: .enabled,
            tokenProvider: MockTokenProvider()
        )

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain
        )

        #expect(client.telemetry.value != nil)
    }

    @Test("Factory sends Auth0-Client header identifying UI Components SDK")
    func testAuth0ClientHeaderContent() {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: .enabled,
            tokenProvider: MockTokenProvider()
        )

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: makeMockSession()
        )

        // Decode the telemetry value to verify it contains "Auth0UniversalComponents"
        guard let telemetryValue = client.telemetry.value,
              let data = Data(base64URLEncoded: telemetryValue),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            Issue.record("Could not decode telemetry header value")
            return
        }

        #expect(name == "Auth0UniversalComponents")
    }

    @Test("Factory includes SDK version in header")
    func testAuth0ClientHeaderVersion() {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: .enabled,
            tokenProvider: MockTokenProvider()
        )

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: makeMockSession()
        )

        guard let telemetryValue = client.telemetry.value,
              let data = Data(base64URLEncoded: telemetryValue),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let headerVersion = json["version"] as? String else {
            Issue.record("Could not decode telemetry header value")
            return
        }

        #expect(headerVersion == Auth0UniversalComponents.version)
    }

    @Test("Factory includes Auth0.swift core version in env")
    func testAuth0ClientHeaderCoreVersion() {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: .enabled,
            tokenProvider: MockTokenProvider()
        )

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: makeMockSession()
        )

        guard let telemetryValue = client.telemetry.value,
              let data = Data(base64URLEncoded: telemetryValue),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: String],
              let coreVersion = env["core"] else {
            Issue.record("Could not decode telemetry env")
            return
        }

        // Core version should be Auth0.swift's version (non-empty)
        #expect(!coreVersion.isEmpty)
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}
