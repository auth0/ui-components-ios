import Testing
import Foundation
@testable import Auth0UniversalComponents
import Auth0

@Suite(.serialized)
struct MyAccountClientFactoryTests {

    private let mockDomain = "test-tenant.auth0.com"
    private let mockToken = "mock_access_token"

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test("Factory creates client with Auth0-Client header")
    func testCreatesClientWithTelemetryHeader() async {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            tokenProvider: MockTokenProvider()
        )

        let session = makeMockSession()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest"]
            )!
            let data = Data("""
            {"id":"totp|test","type":"totp","confirmed":true,"usage":["secondary"],"created_at":"2025-01-01T00:00:00.000Z"}
            """.utf8)
            return (response, data)
        }

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: session
        )

        // Make a request to capture headers
        _ = try? await client.authenticationMethods.enrollTOTP().start()

        #expect(capturedRequest != nil)
        #expect(capturedRequest?.value(forHTTPHeaderField: "Auth0-Client") != nil)
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
            tokenProvider: MockTokenProvider()
        )

        // Just verify it doesn't crash
        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain
        )

        #expect(client != nil)
    }

    @Test("Factory sends Auth0-Client header identifying UI Components SDK")
    func testAuth0ClientHeaderContent() async {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            tokenProvider: MockTokenProvider()
        )

        let session = makeMockSession()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest"]
            )!
            let data = Data("""
            {"id":"totp|test","type":"totp","confirmed":true,"usage":["secondary"],"created_at":"2025-01-01T00:00:00.000Z"}
            """.utf8)
            return (response, data)
        }

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: session
        )

        _ = try? await client.authenticationMethods.enrollTOTP().start()

        guard let headerValue = capturedRequest?.value(forHTTPHeaderField: "Auth0-Client"),
              let data = Data(base64URLEncoded: headerValue),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            Issue.record("Could not decode Auth0-Client header")
            return
        }

        #expect(name == Auth0UniversalComponents.libraryName)
    }

    @Test("Factory includes SDK version in header")
    func testAuth0ClientHeaderVersion() async {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            tokenProvider: MockTokenProvider()
        )

        let session = makeMockSession()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest"]
            )!
            let data = Data("""
            {"id":"totp|test","type":"totp","confirmed":true,"usage":["secondary"],"created_at":"2025-01-01T00:00:00.000Z"}
            """.utf8)
            return (response, data)
        }

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: session
        )

        _ = try? await client.authenticationMethods.enrollTOTP().start()

        guard let headerValue = capturedRequest?.value(forHTTPHeaderField: "Auth0-Client"),
              let data = Data(base64URLEncoded: headerValue),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let headerVersion = json["version"] as? String else {
            Issue.record("Could not decode Auth0-Client header")
            return
        }

        #expect(headerVersion == Auth0UniversalComponents.version)
    }

    @Test("Factory includes Auth0.swift core version in env")
    func testAuth0ClientHeaderCoreVersion() async {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client",
            audience: "\(mockDomain)/me/",
            tokenProvider: MockTokenProvider()
        )

        let session = makeMockSession()
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest"]
            )!
            let data = Data("""
            {"id":"totp|test","type":"totp","confirmed":true,"usage":["secondary"],"created_at":"2025-01-01T00:00:00.000Z"}
            """.utf8)
            return (response, data)
        }

        let client = MyAccountClientFactory.create(
            token: mockToken,
            domain: mockDomain,
            session: session
        )

        _ = try? await client.authenticationMethods.enrollTOTP().start()

        guard let headerValue = capturedRequest?.value(forHTTPHeaderField: "Auth0-Client"),
              let data = Data(base64URLEncoded: headerValue),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: String],
              let coreVersion = env["core"] else {
            Issue.record("Could not decode Auth0-Client header env")
            return
        }

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
