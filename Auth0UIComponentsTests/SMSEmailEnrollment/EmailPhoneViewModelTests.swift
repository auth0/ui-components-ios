@testable import Auth0UIComponents
import Foundation
import Auth0
import Testing


@Suite(.serialized)
struct EmailPhoneViewModelTests {
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
    
    private var phoneEnrollmentChallenge: PhoneEnrollmentChallenge? {
        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_gnrnghn"
        do {
            let response: PhoneEnrollmentChallenge = try decodeResponse(json: enrollmentChallengeData, locationHeader: mockLocationHeader)
            return response
        } catch {
            return nil
        }
    }

    private var emailEnrollmentChallenge: EmailEnrollmentChallenge? {
        let mockLocationHeader = "https://\(mockDomain)/me/v1/authentication-methods/totp%7Ctest_gnrnghn"
        do {
            let response: EmailEnrollmentChallenge = try decodeResponse(json: enrollmentChallengeData, locationHeader: mockLocationHeader)
            return response
        } catch {
            return nil
        }
    }

    private var enrollmentChallengeData: Data {
        let mockJsonData = """
        {
            "id": "phone|test_nkfnbkfnb",
            "auth_session": "eS7ZBG9gItW5uA2xk3m8be5DrmbreOT5"
        }
        """.data(using: .utf8)!
        return mockJsonData
    }

    @Test func testInit_initialState() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let vm = await EmailPhoneEnrollmentViewModel(type: .email)
        await MainActor.run {
            #expect(vm.apiCallInProgress == false)
            #expect(vm.errorMessage == nil)
            #expect(vm.phoneNumber.isEmpty)
            #expect(vm.email.isEmpty)
        }
    }
    
    @Test func testStartEnrollment_Phone_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await EmailPhoneEnrollmentViewModel(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCase(session: makeMockSession()),
                                                            type: .sms)
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/phone%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            viewModel.phoneNumber = "1111000222"
            await viewModel.startEnrollment()
            #expect(NavigationStore.shared.path.last == Route.otpScreen(type: .sms, emailOrPhoneNumber: "+11111000222", phoneEnrollmentChallenge: phoneEnrollmentChallenge))
        }
    }
    
    @Test func testStartEnrollment_Email_Success() async throws {
        let mockTokenProvider = MockTokenProvider()
        await NavigationStore.shared.reset()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await EmailPhoneEnrollmentViewModel(startEmailEnrollmentUseCase: StartEmailEnrollmentUseCase(session: makeMockSession()),
                                                            type: .email)
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://\(mockDomain)/me/v1/authentication-methods/emil%7Ctest_nkfnbkfnb"]
                )!
                confirmation()
                return (response, enrollmentChallengeData)
            }
            viewModel.email = "example@auth0.com"
            await viewModel.startEnrollment()
            #expect(NavigationStore.shared.path.last == Route.otpScreen(type: .email, emailOrPhoneNumber: "example@auth0.com", emailEnrollmentChallenge: emailEnrollmentChallenge))
        }
    }

    @Test func navigationTitle() async  {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await EmailPhoneEnrollmentViewModel(type: .sms)
        await MainActor.run {
            #expect(viewModel.navigationTitle == "Add Phone for SMS OTP")
        }
    }
    
    @Test func title() async  {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await EmailPhoneEnrollmentViewModel(type: .sms)
        await MainActor.run {
            #expect(viewModel.title == "Enter your phone number")
        }
    }
    
}
