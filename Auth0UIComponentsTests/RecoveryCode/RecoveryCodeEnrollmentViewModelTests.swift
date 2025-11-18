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

        let vm = await RecoveryCodeEnrollmentViewModel()
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

        let viewModel = await RecoveryCodeEnrollmentViewModel(startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCase(session: makeMockSession()))
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
    
    
    @Test func testConfirmEnrollment() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await RecoveryCodeEnrollmentViewModel(startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCase(session: makeMockSession()), confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCase(session: makeMockSession()))
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
}

