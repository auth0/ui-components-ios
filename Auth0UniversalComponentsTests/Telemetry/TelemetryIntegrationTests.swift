import Testing
import Foundation
@testable import Auth0UniversalComponents
import Auth0

@Suite(.serialized)
struct TelemetryIntegrationTests {

    private let mockDomain = "test-tenant.auth0.com"
    private let mockClientId = "test_client_id"

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func setupSDK(provider: MockTelemetryEventProvider, enabled: Bool = true) {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: TelemetryConfiguration(enabled: enabled, provider: provider),
            tokenProvider: MockTokenProvider()
        )
    }

    // MARK: - ErrorHandler Telemetry Integration

    @MainActor
    @Test("ErrorHandler emits error event for unknown errors")
    func testErrorHandlerTracksUnknownError() async {
        let provider = MockTelemetryEventProvider()
        setupSDK(provider: provider)

        let errorHandler = ErrorHandler()

        // Use NSError which will be classified as "unknown_error"
        let error = NSError(domain: "TestDomain", code: 42, userInfo: nil)

        // ErrorHandler needs a handler conforming to ErrorViewModelHandler
        // We reuse the mock from ErrorHandlerTests pattern
        let handler = TestErrorViewModelHandler()
        await errorHandler.handle(error: error, scope: "openid", handler: handler, retryCallback: {})

        let errorEvents = provider.events(ofCategory: .error)
        #expect(errorEvents.count == 1)
        #expect(errorEvents.first?.name == "unknown_error")
        #expect(errorEvents.first?.properties["error_type"] == "NSError")
        #expect(errorEvents.first?.properties["scope"] == "openid")
    }

    @MainActor
    @Test("ErrorHandler does not emit events when telemetry disabled")
    func testErrorHandlerSuppressedWhenDisabled() async {
        let provider = MockTelemetryEventProvider()
        setupSDK(provider: provider, enabled: false)

        let errorHandler = ErrorHandler()
        let error = NSError(domain: "TestDomain", code: 42, userInfo: nil)
        let handler = TestErrorViewModelHandler()

        await errorHandler.handle(error: error, scope: "openid", handler: handler, retryCallback: {})

        #expect(provider.events.isEmpty)
    }

    // MARK: - ViewModel Screen View Integration

    @MainActor
    @Test("TOTPPushQRCodeViewModel emits screen view on fetch")
    func testTOTPViewModelScreenView() async {
        let provider = MockTelemetryEventProvider()
        setupSDK(provider: provider)

        let viewModel = TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UniversalComponentsSDKInitializer.shared
        )

        let totpData = Data("""
        {
         "id" : "totp|test_id",
         "barcode_uri" : "otpauth://test",
         "manual_input_code" : "CODE123",
         "auth_session" : "session123"
        }
        """.utf8)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest_id"]
            )!
            return (response, totpData)
        }

        await viewModel.fetchEnrollmentChallenge()

        let screenViews = provider.events(ofCategory: .screenView)
        #expect(screenViews.count == 1)
        #expect(screenViews.first?.name == "totp_push_qr")
        #expect(screenViews.first?.properties["factor_type"] == "totp")
    }

    @MainActor
    @Test("TOTPPushQRCodeViewModel emits flow and API events on success")
    func testTOTPViewModelFlowAndApiEvents() async {
        let provider = MockTelemetryEventProvider()
        setupSDK(provider: provider)

        let viewModel = TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UniversalComponentsSDKInitializer.shared
        )

        let totpData = Data("""
        {
         "id" : "totp|test_id",
         "barcode_uri" : "otpauth://test",
         "manual_input_code" : "CODE123",
         "auth_session" : "session123"
        }
        """.utf8)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest_id"]
            )!
            return (response, totpData)
        }

        await viewModel.fetchEnrollmentChallenge()

        let flowEvents = provider.events(ofCategory: .flow)
        #expect(flowEvents.count == 1)
        #expect(flowEvents.first?.name == "enrollment_started")
        #expect(flowEvents.first?.properties["factor_type"] == "totp")

        let apiEvents = provider.events(ofCategory: .apiCall)
        #expect(apiEvents.count == 1)
        #expect(apiEvents.first?.name == "start_totp_enrollment")
        #expect(apiEvents.first?.status == .success)
        #expect(apiEvents.first?.durationMs != nil)
    }

    @MainActor
    @Test("TOTPPushQRCodeViewModel emits failure events on error")
    func testTOTPViewModelFailureEvents() async {
        let provider = MockTelemetryEventProvider()
        setupSDK(provider: provider)

        let viewModel = TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UniversalComponentsSDKInitializer.shared
        )

        MockURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }

        await viewModel.fetchEnrollmentChallenge()

        let apiEvents = provider.events(ofCategory: .apiCall)
        #expect(apiEvents.count == 1)
        #expect(apiEvents.first?.name == "start_totp_enrollment")
        #expect(apiEvents.first?.status == .failure)
        #expect(apiEvents.first?.properties["error_type"] != nil)

        let flowEvents = provider.events(named: "enrollment_failed")
        #expect(flowEvents.count == 1)
        #expect(flowEvents.first?.properties["factor_type"] == "totp")
    }

    @MainActor
    @Test("No events emitted when telemetry disabled in ViewModel")
    func testViewModelNoEventsWhenDisabled() async {
        let provider = MockTelemetryEventProvider()
        setupSDK(provider: provider, enabled: false)

        let viewModel = TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UniversalComponentsSDKInitializer.shared
        )

        let totpData = Data("""
        {
         "id" : "totp|test_id",
         "barcode_uri" : "otpauth://test",
         "manual_input_code" : "CODE123",
         "auth_session" : "session123"
        }
        """.utf8)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Location": "https://\(self.mockDomain)/me/v1/authentication-methods/totp%7Ctest_id"]
            )!
            return (response, totpData)
        }

        await viewModel.fetchEnrollmentChallenge()

        #expect(provider.events.isEmpty)
    }

    // MARK: - SDK Initializer Telemetry Configuration

    @Test("SDK initializer with default telemetry config enables telemetry")
    func testDefaultTelemetryEnabled() async {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: "\(mockDomain)/me/",
            tokenProvider: MockTokenProvider()
        )

        let config = await Auth0UniversalComponentsSDKInitializer.shared.telemetryConfiguration
        #expect(config.enabled == true)
    }

    @Test("SDK initializer with disabled telemetry config")
    func testExplicitTelemetryDisabled() async {
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: "\(mockDomain)/me/",
            telemetryConfiguration: .disabled,
            tokenProvider: MockTokenProvider()
        )

        let config = await Auth0UniversalComponentsSDKInitializer.shared.telemetryConfiguration
        #expect(config.enabled == false)
        #expect(TelemetryManager.shared.enabled == false)
    }

    // MARK: - Helpers

    @MainActor
    class TestErrorViewModelHandler: ErrorViewModelHandler {
        var showLoader: Bool = false
        var errorViewModel: Auth0UniversalComponents.ErrorScreenViewModel?
    }
}
