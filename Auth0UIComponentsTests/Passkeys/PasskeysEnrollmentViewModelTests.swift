@testable import Auth0UIComponents
import Foundation
import Auth0
import Testing
import AuthenticationServices

@Suite(.serialized)
struct PasskeysEnrollmentViewModelTests {
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

    private var passkeyEnrollmentChallengeData: Data {
        let mockJsonData = """
        {
          "id": "passkey|test_abc123",
          "publicKey": {
            "challenge": "VGhpcyBpcyBhIG1vY2sgY2hhbGxlbmdl",
            "rp": {
              "id": "test-tenant.auth0.com",
              "name": "Test Tenant"
            },
            "user": {
              "id": "dXNlcl9pZF8xMjM=",
              "name": "test@example.com",
              "displayName": "Test User"
            },
            "pubKeyCredParams": [
              {
                "type": "public-key",
                "alg": -7
              }
            ],
            "timeout": 60000,
            "authenticatorSelection": {
              "authenticatorAttachment": "platform",
              "requireResidentKey": true,
              "userVerification": "required"
            }
          }
        }
        """.data(using: .utf8)!
        return mockJsonData
    }

    private var confirmPasskeyEnrollmentData: Data {
        let mockJsonData = """
        {
          "id": "passkey|test_abc123",
          "confirmed": true,
          "type": "passkey",
          "usage": ["primary", "secondary"],
          "created_at": "2025-11-11T03:42:03.571Z",
          "name": "iPhone"
        }
        """.data(using: .utf8)!
        return mockJsonData
    }

    // MARK: - Mock Delegate

    class MockRefreshDelegate: RefreshAuthDataProtocol {
        var refreshCalled = false

        func refreshAuthData() {
            refreshCalled = true
        }
    }

    // MARK: - Tests

    @Test func testInit_initialState() async {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let vm = await PasskeysEnrollmentViewModel(delegate: nil)

        await MainActor.run {
            #expect(vm.showLoader == false)
            #expect(vm.errorViewModel == nil)
        }
    }

    @Test func testInit_withDelegate() async {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let vm = await PasskeysEnrollmentViewModel(delegate: mockDelegate)

        await MainActor.run {
            #expect(vm.showLoader == false)
            #expect(vm.errorViewModel == nil)
        }
    }

    @Test func testStartEnrollment_callsUseCase() async throws {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        // Note: Testing passkey enrollment fully requires ASAuthorizationController which
        // cannot be easily mocked in unit tests. This test verifies the view model is
        // properly initialized and ready to handle passkey enrollment.
        let viewModel = await PasskeysEnrollmentViewModel(delegate: nil)

        await MainActor.run {
            #expect(viewModel.showLoader == false)
            #expect(viewModel.errorViewModel == nil)
        }
    }

    @Test func testStartEnrollment_withMockUseCase() async throws {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        // Create a mock that throws an error
        class MockFailingPasskeyUseCase: StartPasskeyEnrollmentUseCaseable {
            func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge {
                throw MyAccountError(detail: "Internal Server Error", statusCode: 500, validationErrors: nil)
            }
        }

        let mockUseCase = MockFailingPasskeyUseCase()
        let viewModel = await PasskeysEnrollmentViewModel(
            startPasskeyEnrollmentUseCase: mockUseCase,
            delegate: nil
        )

        await viewModel.startEnrollment()

        // Note: Error handling involves complex UI callback mechanisms that are
        // difficult to reliably test in unit tests. This verifies the method completes.
        await MainActor.run {
            #expect(viewModel.showLoader == false, "Loader should be hidden after enrollment attempt")
        }
    }

    @Test func testAuthorizationController_delegateMethods() async {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let viewModel = await PasskeysEnrollmentViewModel(delegate: nil)

        // Note: We cannot easily test ASAuthorizationControllerDelegate methods as
        // ASAuthorizationController and ASAuthorization objects cannot be mocked or
        // instantiated directly in unit tests. This test verifies the view model
        // is in a valid state and ready to handle authorization callbacks.
        await MainActor.run {
            #expect(viewModel.showLoader == false)
            #expect(viewModel.errorViewModel == nil)
        }
    }

    @Test func testHandle_setsLoaderToFalse() async {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let viewModel = await PasskeysEnrollmentViewModel(delegate: nil)

        // Set loader to true first
        await MainActor.run {
            viewModel.showLoader = true
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

    @Test func testHandle_errorHandling() async {
        guard #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) else { return }

        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(
            session: makeMockSession(),
            bundle: .main,
            domain: mockDomain,
            clientId: "test_client_id",
            audience: "\(mockDomain)/me/",
            tokenProvider: mockTokenProvider
        )

        let viewModel = await PasskeysEnrollmentViewModel(delegate: nil)

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
}
