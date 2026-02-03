// swiftlint:disable type_body_length

import Testing
import Foundation
@testable import Auth0UIComponents
import Auth0

@Suite(.serialized)
struct OTPViewModelTests {
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

    private var phoneEnrollmentChallengeData: Data {
        let mockJsonData = """
        {
            "id": "phone|Ctest_nkfnbkfnb",
            "auth_session": "eS7ZBG9gItW5uA2xk3m8be5DrmbreOT5"
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

    private var emailEnrollmentChallenge: EmailEnrollmentChallenge? {
        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_gnrnghn"
        do {
            let response: EmailEnrollmentChallenge = try decodeResponse(json: phoneEnrollmentChallengeData, locationHeader: mockLocationHeader)
            return response
        } catch {
            return nil
        }
    }
    
    private var phoneEnrollmentChallenge: PhoneEnrollmentChallenge? {
        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_gnrnghn"
        do {
            let response: PhoneEnrollmentChallenge = try decodeResponse(json: phoneEnrollmentChallengeData, locationHeader: mockLocationHeader)
            return response
        } catch {
            return nil
        }
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

    init() async throws {
        Auth0UIComponentsSDKInitializer.reset()
    }

    @Test func testInit_initialState() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let vm = await OTPViewModel(totpEnrollmentChallenge: totpEnrollmentChallenge, emailEnrollmentChallenge: nil, phoneEnrollmentChallenge: nil, type: .totp, delegate: nil)
        await MainActor.run {
            #expect(vm.showLoader == false)
            #expect(vm.errorMessage == nil)
            #expect(vm.apiCallInProgress == false)
            #expect(vm.otpText.isEmpty)
        }
    }
    
    @Test func testConfirmEnrollment_TOTP_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCase(session: makeMockSession()),
                                           confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCase(session: makeMockSession()),
                                           startEmailEnrollmentUseCase: StartEmailEnrollmentUseCase(session: makeMockSession()),
                                           confirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCase(session: makeMockSession()),
                                           confirmTOTPEnrollmentUSeCase:  ConfirmTOTPEnrollmentUseCase(session: makeMockSession()),
                                           totpEnrollmentChallenge: totpEnrollmentChallenge,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: nil,
                                           type: .totp, delegate: nil
        )

        // Set OTP text before confirming
        await MainActor.run {
            viewModel.otpText = "123456"
        }

        await confirmation(expectedCount: 1) { @MainActor confirmation in
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
            await viewModel.confirmEnrollment()
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .totp, authMethods: []))
        }
    }

    @Test func testConfirmEnrollment_Email_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCase(session: makeMockSession()),
                                           confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCase(session: makeMockSession()),
                                           startEmailEnrollmentUseCase: StartEmailEnrollmentUseCase(session: makeMockSession()),
                                           confirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCase(session: makeMockSession()),
                                           confirmTOTPEnrollmentUSeCase:  ConfirmTOTPEnrollmentUseCase(session: makeMockSession()),
                                           totpEnrollmentChallenge:  nil,
                                           emailEnrollmentChallenge: emailEnrollmentChallenge,
                                           phoneEnrollmentChallenge: nil,
                                           type: .email, delegate: nil
        )

        // Set OTP text before confirming
        await MainActor.run {
            viewModel.otpText = "123456"
        }

        await confirmation(expectedCount: 1) { @MainActor confirmation in
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
            await viewModel.confirmEnrollment()
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .email, authMethods: []))
        }
    }

    @Test func testConfirmEnrollment_Phone_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCase(session: makeMockSession()),
                                           totpEnrollmentChallenge:  nil,
                                           emailEnrollmentChallenge: nil,
                                           phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                                           type: .sms,
                                           delegate: nil
        )

        // Set OTP text before confirming
        await MainActor.run {
            viewModel.otpText = "123456"
        }

        await confirmation(expectedCount: 1) { @MainActor confirmation in
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
            await viewModel.confirmEnrollment()
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .sms, authMethods: []))
        }
    }
    
    @Test
    func testEmailOrSMS() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(type: .sms, delegate: nil)
        await MainActor.run {
            #expect(viewModel.isEmailOrSMS)
        }
    }
    
    @Test func navigationTitle() async  {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(type: .sms, delegate: nil)
        await MainActor.run {
            #expect(viewModel.navigationTitle == "Add Phone for SMS OTP")
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

        let vm = await OTPViewModel(totpEnrollmentChallenge: totpEnrollmentChallenge, emailEnrollmentChallenge: nil, phoneEnrollmentChallenge: nil, type: .totp, delegate: mockDelegate)
        await MainActor.run {
            #expect(vm.showLoader == false)
            #expect(vm.errorMessage == nil)
        }
    }

    @Test func testConfirmEnrollment_TOTP_callsDelegate() async throws {
        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            confirmTOTPEnrollmentUSeCase: ConfirmTOTPEnrollmentUseCase(session: makeMockSession()),
            totpEnrollmentChallenge: totpEnrollmentChallenge,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: nil,
            type: .totp,
            delegate: mockDelegate
        )

        // Set OTP text before confirming
        await MainActor.run {
            viewModel.otpText = "123456"
        }

        await confirmation(expectedCount: 1) { @MainActor confirmation in
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
            await viewModel.confirmEnrollment()

            // Verify delegate was called
            #expect(mockDelegate.refreshCalled == true, "Delegate should be called after successful enrollment")
            #expect(NavigationStore.shared.path.last == Route.filteredAuthListScreen(type: .totp, authMethods: []))
        }
    }

    // MARK: - Error Cases

    @Test func testConfirmEnrollment_TOTP_handlesAPIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            confirmTOTPEnrollmentUSeCase: ConfirmTOTPEnrollmentUseCase(session: makeMockSession()),
            totpEnrollmentChallenge: totpEnrollmentChallenge,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: nil,
            type: .totp,
            delegate: nil
        )

        // Set OTP text before confirming
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
                    "error": "Bad Request",
                    "message": "Invalid OTP code"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.confirmEnrollment()

            // Verify error was handled
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress after error")
            #expect(viewModel.errorMessage != nil, "Error message should be set on confirmation failure")
        }
    }

    @Test func testConfirmEnrollment_Email_handlesAPIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            confirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCase(session: makeMockSession()),
            totpEnrollmentChallenge: nil,
            emailEnrollmentChallenge: emailEnrollmentChallenge,
            phoneEnrollmentChallenge: nil,
            type: .email,
            delegate: nil
        )

        // Set OTP text before confirming
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
                    "error": "Bad Request",
                    "message": "Invalid email OTP code"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.confirmEnrollment()

            // Verify error was handled
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress after error")
            #expect(viewModel.errorMessage != nil, "Error message should be set on confirmation failure")
        }
    }

    @Test func testConfirmEnrollment_Phone_handlesAPIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCase(session: makeMockSession()),
            totpEnrollmentChallenge: nil,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: phoneEnrollmentChallenge,
            type: .sms,
            delegate: nil
        )

        // Set OTP text before confirming
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
                    "error": "Bad Request",
                    "message": "Invalid phone OTP code"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.confirmEnrollment()

            // Verify error was handled
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress after error")
            #expect(viewModel.errorMessage != nil, "Error message should be set on confirmation failure")
        }
    }

    @Test func testConfirmEnrollment_withoutChallenge() async {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            totpEnrollmentChallenge: nil,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: nil,
            type: .totp,
            delegate: nil
        )

        // Call confirmEnrollment without a challenge
        await viewModel.confirmEnrollment()

        // Should not crash and should remain in initial state
        await MainActor.run {
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress")
        }
    }

    // MARK: - State Management Tests

    @Test func testApiCallInProgress_stateManagement() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            confirmTOTPEnrollmentUSeCase: ConfirmTOTPEnrollmentUseCase(session: makeMockSession()),
            totpEnrollmentChallenge: totpEnrollmentChallenge,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: nil,
            type: .totp,
            delegate: nil
        )

        // Verify initial state
        await MainActor.run {
            #expect(viewModel.apiCallInProgress == false, "API call should not be in progress initially")
        }

        await confirmation(expectedCount: 1) { @MainActor confirmation in
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

            await viewModel.confirmEnrollment()

            // Verify state after successful confirm
            #expect(viewModel.apiCallInProgress == false, "API call should complete")
        }
    }

    @Test func testOTPText_validation() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await OTPViewModel(
            totpEnrollmentChallenge: totpEnrollmentChallenge,
            emailEnrollmentChallenge: nil,
            phoneEnrollmentChallenge: nil,
            type: .totp,
            delegate: nil
        )

        // Verify OTP text starts empty
        await MainActor.run {
            #expect(viewModel.otpText.isEmpty, "OTP text should start empty")

            // Set OTP text
            viewModel.otpText = "123456"
            #expect(viewModel.otpText == "123456", "OTP text should update correctly")
        }
    }
}

