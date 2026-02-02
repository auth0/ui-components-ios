import Testing
import Foundation
@testable import Auth0UIComponents
import Auth0

@Suite(.serialized)
struct ErrorHandlerTests {
    private let mockToken = "mock_access_token_123"
    private let mockDomain = "test-tenant.auth0.com"
    private let mockClientId = "test_client_id"
    private let mockAudience = "https://test-tenant.auth0.com/me/"

    @MainActor
    class MockErrorViewModelHandler: ErrorViewModelHandler {
        var showLoader: Bool = false
        var errorViewModel: Auth0UIComponents.ErrorScreenViewModel? = nil
    }

    @MainActor
    class MockErrorMessageHandler: ErrorMessageHandler {
        var errorMessage: String? = nil
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @MainActor
    @Test("ErrorHandler initializes with default dependencies")
    func testInit_withDefaultDependencies() async throws {
        _ = ErrorHandler()
        // Test passes if no crash occurs
    }

    @MainActor
    @Test("ErrorHandler initializes with custom dependencies")
    func testInit_withCustomDependencies() async throws {
        let mockSession = makeMockSession()
        let tokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.initialize(
            session: mockSession,
            bundle: Bundle.main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: mockAudience,
            tokenProvider: tokenProvider
        )

        let dependencies = Auth0UIComponentsSDKInitializer.shared
        _ = ErrorHandler(dependencies: dependencies)
        // Test passes if no crash occurs
    }

    @MainActor
    @Test("ErrorViewModelHandler protocol conformance")
    func testErrorViewModelHandler_protocolConformance() async throws {
        let handler = MockErrorViewModelHandler()

        handler.showLoader = true
        handler.errorViewModel = Auth0UIComponents.ErrorScreenViewModel(
            title: "Test Error",
            subTitle: Foundation.AttributedString("Test Description"),
            buttonTitle: "Try again",
            textTap: {},
            buttonClick: {}
        )

        #expect(handler.showLoader == true)
        #expect(handler.errorViewModel != nil)
        #expect(handler.errorViewModel?.title == "Test Error")
    }

    @MainActor
    @Test("ErrorMessageHandler protocol conformance")
    func testErrorMessageHandler_protocolConformance() async throws {
        let handler = MockErrorMessageHandler()

        handler.errorMessage = "Test error message"

        #expect(handler.errorMessage == "Test error message")
    }

    @MainActor
    @Test("ErrorHandler integration with OTPViewModel - API error handling")
    func testErrorHandlerIntegration_OTPViewModel_APIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let totpEnrollmentChallengeData = """
        {
         "id" : "totp|test_nkfnbkfnb",
         "barcode_uri" : "otpauth://test",
         "manual_input_code" : "CODE123",
         "auth_session" : "session123"
        }
        """.data(using: .utf8)!

        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"
        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey(rawValue: "locationHeader")!] = mockLocationHeader
        let totpChallenge = try decoder.decode(TOTPEnrollmentChallenge.self, from: totpEnrollmentChallengeData)

        let viewModel = await OTPViewModel(
            confirmTOTPEnrollmentUSeCase: ConfirmTOTPEnrollmentUseCase(session: makeMockSession()),
            totpEnrollmentChallenge: totpChallenge,
            type: .totp,
            emailOrPhoneNumber: nil,
            delegate: nil
        )

        await MainActor.run {
            viewModel.otpText = "123456"
        }

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                let errorData = """
                {
                    "statusCode": 400,
                    "error": "invalid_grant",
                    "error_description": "Invalid code"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.confirmEnrollment()

            // Verify ErrorHandler correctly set errorMessage through ErrorMessageHandler protocol
            #expect(viewModel.errorMessage != nil, "ErrorHandler should set errorMessage for OTP errors")
        }
    }

    @MainActor
    @Test("ErrorHandler integration with TOTPPushQRCodeViewModel - network error")
    func testErrorHandlerIntegration_TOTPPushViewModel_NetworkError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let viewModel = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UIComponentsSDKInitializer.shared,
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                confirmation()
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
            }

            await viewModel.fetchEnrollmentChallenge()

            // Verify ErrorHandler correctly set errorViewModel through ErrorViewModelHandler protocol
            #expect(viewModel.errorViewModel != nil, "ErrorHandler should set errorViewModel for network errors")
            #expect(viewModel.showLoader == false, "ErrorHandler should set showLoader to false on error")
        }
    }

    @MainActor
    @Test("ErrorHandler integration with SavedAuthenticatorsScreenViewModel - API error")
    func testErrorHandlerIntegration_SavedAuthenticators_APIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: mockClientId,
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()),
            type: .totp,
            authenticationMethods: [],
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                let errorData = """
                {
                    "statusCode": 500,
                    "error": "Internal Server Error",
                    "message": "Server error occurred"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.loadData()

            // Verify ErrorHandler correctly set errorViewModel through ErrorViewModelHandler protocol
            #expect(viewModel.errorViewModel != nil, "ErrorHandler should set errorViewModel for API errors")
            #expect(viewModel.showLoader == false, "ErrorHandler should set showLoader to false on error")
        }
    }

    @MainActor
    @Test("ErrorHandler sets showLoader to false on error")
    func testHandle_setsShowLoaderToFalse() async throws {
        let handler = MockErrorViewModelHandler()
        handler.showLoader = true

        // Create a simple test error
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let errorHandler = ErrorHandler()

        await errorHandler.handle(
            error: testError,
            scope: "openid",
            handler: handler,
            retryCallback: {}
        )

        // Even for unknown errors, showLoader should be set to false
        #expect(handler.showLoader == false, "ErrorHandler should always set showLoader to false")
    }
}
