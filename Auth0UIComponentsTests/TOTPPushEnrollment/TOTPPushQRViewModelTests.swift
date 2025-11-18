import Testing
import Foundation
@testable import Auth0UIComponents
import Auth0

@Suite(.serialized)
struct TOTPPushQRCodeViewModelTests {
    private let mockToken = "mock_access_token_123"
    private let mockDomain = "test-tenant.auth0.com"
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
    
    func decodeResponse<T: Decodable>(json: Data, locationHeader: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey(rawValue: "locationHeader")!] = locationHeader
        return try decoder.decode(T.self, from: json)
    }

    private var totpEnrollmentChallengeData: Data {
        let mockJsonData = """
               {
                "id" : "totp|test_nkfnbkfnb",
                "barcode_uri" : "otpauth://test-tenant-test:auth0%7C6889c0a8a1354b593f53e35f?secret&issuer=test-tenant-test&algorithm=SHA1&digits=6&period=30",
                "manual_input_code" : "N47HCYSDHRKWWSLJONYEQ7LXLV5XEMC5",
                "auth_session" : "jfnfgnbkbnLfiurfg"
               }
        """.data(using: .utf8)!
        return mockJsonData
    }

    private var totpEnrollmentChallenge: TOTPEnrollmentChallenge? {
        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"

        do {
            let response: TOTPEnrollmentChallenge = try decodeResponse(json: totpEnrollmentChallengeData, locationHeader: mockLocationHeader)
            return response
        } catch {
            return nil
        }
    }

    private var pushEnrollmentChallengeData: Data  {
        let data = """
            {
             "id" : "push-notification|test_nkfnbkfnb",
             "auth_session" : "jfnfgnbkbnLfiurfg",
             "barcode_uri" : "otpauth://totp/test-tenant-test:auth0%7C689b3c89a51b6e7534dd0bed?enrollment_tx_id=epz2WsTxWCRBNOGJeZGdDY5Q0X28BpEm&base_url=https%3A%2F%2F\(mockDomain)%2Fappliance-mfa"
            }
            """
            .data(using: .utf8)!
        return data
    }
    
    
    private var confirmEnrollmentTOTPData: Data {
       let data =
        """
        {
         "id" : "totp|test_nkfnbkfnb",
         "confirmed" : true,
         "type" : "totp",
         "usage" : [
          "secondary"
         ],
         "created_at" : "2025-07-30T13:08:49.508Z"
        }
        """.data(using: .utf8)!
        return data
    }

    @Test func testInit_initialState() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)
        let vm = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UIComponentsSDKInitializer.shared
        )
        await MainActor.run {
            #expect(vm.showLoader == true)
            #expect(vm.qrCodeImage == nil)
            #expect(vm.manualInputCode == nil)
            #expect(vm.errorViewModel == nil)
            #expect(vm.apiCallInProgress == false)
            
        }
    }
    
    @Test func testFetchEnrollmentChallenge_TOTP_Success() async throws {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UIComponentsSDKInitializer.shared
        )
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, totpEnrollmentChallengeData)
            }
            await viewModel.fetchEnrollmentChallenge()
            #expect(viewModel.manualInputCode == "N47HCYSDHRKWWSLJONYEQ7LXLV5XEMC5")
        }
    }
    
    @Test func testFetchEnrollmentChallenge_Push_Success() async throws {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UIComponentsSDKInitializer.shared
        )
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "\(mockDomain)/me/v1/authentication-methods/push%7Ctest_3M5JGzX40630NuwY"]
                )!
                confirmation()
                return (response, pushEnrollmentChallengeData)
            }
            await viewModel.fetchEnrollmentChallenge()
            #expect(viewModel.qrCodeImage != nil)
        }
    }

    @Test func testConfirmEnrollmentChallenge_TOTP_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .totp,
            dependencies: Auth0UIComponentsSDKInitializer.shared
        )
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, totpEnrollmentChallengeData)
            }
            await viewModel.fetchEnrollmentChallenge()
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, confirmEnrollmentTOTPData)
            }
            await viewModel.handleContinueButtonTap()
            if case let .otpScreen(type, _, challenge, _, _) = NavigationStore.shared.path.last {
                #expect(type == .totp)
                #expect(challenge?.authenticationId == totpEnrollmentChallenge?.authenticationId)
                #expect(challenge?.authenticationSession == totpEnrollmentChallenge?.authenticationSession)
            } else {
                Issue.record("Navigation path was not .otpScreen, was \(String(describing: NavigationStore.shared.path.last))")
            }
        }
    }
    
    @Test func testConfirmEnrollmentChallenge_Push_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            confirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCase(session: makeMockSession()),
            type: .pushNotification,
            dependencies: Auth0UIComponentsSDKInitializer.shared
        )
        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, pushEnrollmentChallengeData)
            }
            await viewModel.fetchEnrollmentChallenge()
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, confirmEnrollmentTOTPData)
            }
            await viewModel.handleContinueButtonTap()
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .pushNotification, authMethods: []))
        }
    }

    @Test
    func testNavigationTitle() async {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)
        let viewModel = await TOTPPushQRCodeViewModel(
            startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCase(session: makeMockSession()),
            startPushEnrollmentUseCase: StartPushEnrollmentUseCase(session: makeMockSession()),
            type: .pushNotification,
            dependencies: Auth0UIComponentsSDKInitializer.shared
        )
        await MainActor.run {
            #expect(viewModel.navigationTitle() == "Add push notification")
        }
    }

}
