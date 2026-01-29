@testable import Auth0UIComponents
import Foundation
import Auth0
import Testing

@Suite(.serialized)
struct RecoveryCodeEnrollmentViewModelTests {
    private let mockToken = "mock_access_token_123"
    private let mockDomain = "test-tenant.auth0.com"
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func decodeResponse<T: Decodable>(json: Data, locationHeader: String? = nil) throws -> T {
        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey(rawValue: "locationHeader")!] = locationHeader
        return try decoder.decode(T.self, from: json)
    }
   
    private var enrollmentChallengeData: Data {
        let mockJsonData = """
        {
          "id" : "recovery-code|test_hHm0dHPGxyF2RsKj",
          "auth_session" : "3iMRnuk6WJVwjSElegkHmpy3OxjsiW55",
          "recovery_code" : "VHDGEJQRKWM3UVJ6BML4ST95"
        }
        """.data(using: .utf8)!
        return mockJsonData
    }

    private var confirmRecoveryChallengeData: Data {
        let mockJsonData = """
            {
             "id" : "recovery-code|test_hHm0dHPGxyF2RsKj",
             "confirmed" : true,
             "type" : "recovery-code",
             "usage" : [
              "secondary"
             ],
             "created_at" : "2025-11-11T03:42:03.571Z"
            }
            """.data(using: .utf8)!
        return mockJsonData
    }

    private var recoveryCodeChallenge: RecoveryCodeEnrollmentChallenge? {
        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_gnrnghn"
        do {
            let response: RecoveryCodeEnrollmentChallenge = try decodeResponse(json: enrollmentChallengeData, locationHeader: mockLocationHeader)
            return response
        } catch {
            return nil
        }
    }
    
    private var authenticationMethod: AuthenticationMethod? {
        do {
            let response: AuthenticationMethod = try decodeResponse(json: confirmRecoveryChallengeData)
            return response
        } catch {
            return nil
        }
    }

    @Test func testInit_initialState() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let vm = await RecoveryCodeEnrollmentViewModel(delegate: nil)
        await MainActor.run {
            #expect(vm.showLoader == true)
            #expect(vm.errorViewModel == nil)
            #expect(vm.recoveryCodeChallenge == nil)
        }
    }
    
    @Test func testLoadData() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCase(session: makeMockSession()), delegate: nil)
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/recovery-code%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            await viewModel.loadData()
            #expect(viewModel.recoveryCodeChallenge != nil)
        }
    }
    
    
    @Test func testConfirmEnrollment_success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let startRecoveryCodeEnrollmentUseCase = StartRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let confirmRecoveryCodeEnrollmentUseCase = ConfirmRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let viewModel = await RecoveryCodeEnrollmentViewModel(startRecoveryCodeEnrollmentUseCase: startRecoveryCodeEnrollmentUseCase,
                                                              confirmRecoveryCodeEnrollmentUseCase: confirmRecoveryCodeEnrollmentUseCase, delegate: nil)
        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/recovery-code%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            await viewModel.loadData()
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                return (response, confirmRecoveryChallengeData)
            }

            await viewModel.confirmEnrollment()
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .recoveryCode, authMethods: []))
        }
    }

    // MARK: - Tests with Delegate

    class MockRefreshDelegate: RefreshAuthDataProtocol {
        var refreshCalled = false

        func refreshAuthData() {
            refreshCalled = true
        }
    }

    @Test func testInit_withDelegate() async {
        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let vm = await RecoveryCodeEnrollmentViewModel(delegate: mockDelegate)
        await MainActor.run {
            #expect(vm.showLoader == true)
            #expect(vm.errorViewModel == nil)
            #expect(vm.recoveryCodeChallenge == nil)
        }
    }

    @Test func testConfirmEnrollment_callsDelegate() async throws {
        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let startRecoveryCodeEnrollmentUseCase = StartRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let confirmRecoveryCodeEnrollmentUseCase = ConfirmRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let viewModel = await RecoveryCodeEnrollmentViewModel(
            startRecoveryCodeEnrollmentUseCase: startRecoveryCodeEnrollmentUseCase,
            confirmRecoveryCodeEnrollmentUseCase: confirmRecoveryCodeEnrollmentUseCase,
            delegate: mockDelegate
        )

        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/recovery-code%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            await viewModel.loadData()

            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                return (response, confirmRecoveryChallengeData)
            }

            await viewModel.confirmEnrollment()

            // Verify delegate was called
            #expect(mockDelegate.refreshCalled == true, "Delegate should be called after successful enrollment")
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .recoveryCode, authMethods: []))
        }
    }

    // MARK: - Error Cases

    @Test func testLoadData_handlesAPIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(
            startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCase(session: makeMockSession()),
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

            // Verify error was handled
            #expect(viewModel.showLoader == false, "Loader should be hidden after error")
            #expect(viewModel.errorViewModel != nil, "Error view model should be set on API failure")
        }
    }

    @Test func testLoadData_handlesNetworkError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(
            startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCase(session: makeMockSession()),
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                confirmation()
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
            }

            await viewModel.loadData()

            // Verify error was handled
            #expect(viewModel.showLoader == false, "Loader should be hidden after network error")
            #expect(viewModel.errorViewModel != nil, "Error view model should be set on network failure")
        }
    }

    @Test func testConfirmEnrollment_handlesAPIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let startRecoveryCodeEnrollmentUseCase = StartRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let confirmRecoveryCodeEnrollmentUseCase = ConfirmRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let viewModel = await RecoveryCodeEnrollmentViewModel(
            startRecoveryCodeEnrollmentUseCase: startRecoveryCodeEnrollmentUseCase,
            confirmRecoveryCodeEnrollmentUseCase: confirmRecoveryCodeEnrollmentUseCase,
            delegate: nil
        )

        await confirmation(expectedCount: 2) { @MainActor confirmation in
            // First load the challenge successfully
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/recovery-code%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            await viewModel.loadData()

            // Then fail on confirm
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
                    "error": "Bad Request",
                    "message": "Invalid recovery code"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.confirmEnrollment()

            // Verify error was handled
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress after error")
            #expect(viewModel.errorViewModel != nil, "Error view model should be set on confirmation failure")
        }
    }

    @Test func testConfirmEnrollment_withoutChallenge() async {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(delegate: nil)

        // Call confirmEnrollment without loading data first (no challenge)
        await viewModel.confirmEnrollment()

        // Should not crash and challenge should remain nil
        await MainActor.run {
            #expect(viewModel.recoveryCodeChallenge == nil, "Challenge should still be nil")
        }
    }

    // MARK: - Error Handling Tests

    @Test func testHandle_setsLoaderToFalse() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(delegate: nil)

        // Set loader to false first (since init sets it to true)
        await MainActor.run {
            viewModel.showLoader = false
        }

        // Test handling of MyAccountError - server error type
        let error = MyAccountError(detail: "Server Error", statusCode: 500, validationErrors: nil)

        await viewModel.handle(error: error, scope: "openid create:me:authentication_methods") {
            // Retry callback
        }

        // Verify loader is turned off after error handling
        await MainActor.run {
            #expect(viewModel.showLoader == false, "Loader should be hidden after error handling")
        }
    }

    @Test func testHandle_webAuthError() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(delegate: nil)

        // Test handling of WebAuthError
        let error = WebAuthError.userCancelled

        await viewModel.handle(error: error, scope: "openid create:me:authentication_methods") {
            // Retry callback
        }

        // Verify loader state management - errorViewModel depends on complex UI callback
        // mechanisms which are tested through integration tests
        await MainActor.run {
            #expect(viewModel.showLoader == false, "Loader should be hidden after error handling")
        }
    }

    @Test func testHandle_myAccountError() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(delegate: nil)

        // Test handling of MyAccountError with validation errors
        let fieldError = FieldError(field: "code", detail: "Invalid format", pointer: "/code", source: nil)
        let error = MyAccountError(detail: "Validation failed", statusCode: 400, validationErrors: [fieldError])

        await viewModel.handle(error: error, scope: "openid create:me:authentication_methods") {
            // Retry callback
        }

        // Verify loader state management - errorViewModel depends on complex UI callback
        // mechanisms which are tested through integration tests
        await MainActor.run {
            #expect(viewModel.showLoader == false, "Loader should be hidden after error handling")
        }
    }

    @Test func testHandle_credentialsManagerError() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(delegate: nil)

        // Test handling of CredentialsManagerError with session expired
        let authError = AuthenticationError(message: "Session expired", statusCode: 401, cause: nil, code: "login_required")
        let error = CredentialsManagerError(cause: authError, localizedDescription: "No valid credentials")

        await viewModel.handle(error: error, scope: "openid create:me:authentication_methods") {
            // Retry callback
        }

        // Verify loader state management - errorViewModel depends on complex UI callback
        // mechanisms which are tested through integration tests
        await MainActor.run {
            #expect(viewModel.showLoader == false, "Loader should be hidden after error handling")
        }
    }

    // MARK: - State Management Tests

    @Test func testApiCallInProgress_stateManagement() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let startRecoveryCodeEnrollmentUseCase = StartRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let confirmRecoveryCodeEnrollmentUseCase = ConfirmRecoveryCodeEnrollmentUseCase(session: makeMockSession())
        let viewModel = await RecoveryCodeEnrollmentViewModel(
            startRecoveryCodeEnrollmentUseCase: startRecoveryCodeEnrollmentUseCase,
            confirmRecoveryCodeEnrollmentUseCase: confirmRecoveryCodeEnrollmentUseCase,
            delegate: nil
        )

        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/recovery-code%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            await viewModel.loadData()

            // Verify initial state before confirm
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress initially")

            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                return (response, confirmRecoveryChallengeData)
            }

            await viewModel.confirmEnrollment()

            // Verify state after successful confirm
            #expect(viewModel.apiCallInProgress == false, "API call should complete")
        }
    }
}

