# AI Agent Guidelines for Auth0 UI Components iOS SDK

This document provides context and guidelines for AI coding assistants working with the Auth0 UI Components iOS SDK codebase.

## Project Overview

**Auth0 UI Components iOS SDK** provides pre-built, customizable SwiftUI components for managing Multi-Factor Authentication (MFA) enrollment and verification. Built on top of [Auth0.swift](https://github.com/auth0/Auth0.swift) and Auth0's My Account APIs, this SDK simplifies implementing MFA flows across iOS 16+, macOS 14+, and visionOS 1.0+.

> ⚠️ **BETA RELEASE** - This SDK is currently in beta. APIs may change before the stable release.

### Supported Platforms

- **iOS**: 16.0+
- **macOS**: 14.0+
- **visionOS**: 1.0+
- **Swift**: 6.0+
- **Xcode**: 26.0+

## Repository Structure

```text
ui-components-ios/
├── Auth0UIComponents/                  # Main SDK Target
│   ├── AuthMethodsHome/                # List & manage MFA factors
│   │   ├── Domain/                     # GetAuthMethodsUseCase, GetFactorsUseCase
│   │   └── Presentation/               # MyAccountAuthMethodsView(Model)
│   ├── EmailSMSEnrollment/             # SMS & Email OTP enrollment
│   │   ├── Domain/                     # Start/Confirm enrollment UseCases
│   │   └── Presentation/               # EmailPhoneEnrollmentView(Model)
│   ├── TOTPPushEnrollment/             # TOTP & Push enrollment
│   │   ├── Domain/                     # Start/Confirm TOTP/Push UseCases
│   │   └── Presentation/               # TOTPPushQRCodeView, OTPView
│   ├── RecoveryCode/                   # Recovery code generation
│   │   ├── Domain/                     # Start/Confirm recovery code UseCases
│   │   └── Presentation/               # RecoveryCodeEnrollmentView(Model)
│   ├── SaveAuthenticators/             # Manage saved factors
│   │   ├── Domain/                     # DeleteAuthMethodUseCase
│   │   └── Presentation/               # SavedAuthenticatorsScreen(ViewModel)
│   ├── Core/Utils/                     # Shared utilities
│   │   ├── OTPTextField.swift          # OTP code input component
│   │   ├── CountryCodePicker/          # Phone number country selection
│   │   ├── Error/                      # ErrorScreen & ViewModel
│   │   └── Toast*.swift                # Toast notifications
│   ├── TokenProvider.swift             # Token management protocol
│   └── Auth0UIComponentsSDKInitializer.swift  # SDK setup
├── Auth0UIComponentsTests/             # Unit Tests
├── AppUIComponents/                    # Sample App
├── Package.swift                       # Swift Package Manager
├── Auth0UIComponents.xcodeproj         # Xcode Project
├── Cartfile                            # Carthage dependencies
└── README.md                           # Public documentation
```

## Architecture Overview

### Clean Architecture Layers

1. **Presentation Layer**
   - **Views**: SwiftUI Views for MFA enrollment/management
   - **ViewModels**: State management and presentation logic
   - **Coordinators**: Navigation and flow management (via NavigationStore)
   - **Responsibility**: User interface and user interaction

2. **Domain Layer**
   - **Entities**: Auth methods, factors, enrollment challenges
   - **UseCases**: MFA enrollment/verification business logic
   - **Protocols**: Abstractions for Auth0 API interactions
   - **Responsibility**: Business rules independent of UI or Auth0 implementation details

### MVVM Pattern

```
View ←→ ViewModel ←→ UseCase ←→ Auth0 API
  ↓         ↓          ↓
State   Published   Protocol
        Properties  Abstraction
```

- **View**: Observes ViewModel state, renders UI
- **ViewModel**: Transforms domain data into view state, handles user actions
- **UseCase**: Encapsulates Auth0 API calls and business logic
- **No direct View ↔ Domain communication**

## Auth0 Integration

### Dependencies

This SDK depends on:
- **[Auth0.swift](https://github.com/auth0/Auth0.swift)** - Core Auth0 authentication
- **SimpleKeychain** - Secure credential storage
- **JWTDecode.swift** - JWT token parsing

### TokenProvider Protocol

All API calls require implementing the `TokenProvider` protocol:

```swift
protocol TokenProvider {
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials
}
```

This abstraction allows you to manage token retrieval (from CredentialsManager, cache, etc.) separately from UI components.

### SDK Initialization

**Required** before using any UI components:

```swift
import Auth0UIComponents

@main
struct MyApp: App {
    init() {
        Auth0UIComponentsSDKInitializer.initialize(
            tokenProvider: YourTokenProvider()
        )
        // OR with explicit configuration:
        // Auth0UIComponentsSDKInitializer.initialize(
        //     domain: "your-tenant.auth0.com",
        //     clientId: "your-client-id",
        //     audience: "https://your-tenant.auth0.com/me/",
        //     tokenProvider: YourTokenProvider()
        // )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Universal Login & Step-Up Authentication

This SDK uses **Universal Login** for MFA step-up flows. When an MFA-required error is encountered, the SDK automatically initiates Universal Login.

**Prerequisites:**
1. **Associated Domains** capability in Xcode
2. **Callback URLs** configured in Auth0 dashboard
3. **URL Scheme** matching your bundle identifier

See [Auth0.swift documentation](https://github.com/auth0/Auth0.swift) for detailed setup.

## Key Technical Decisions

### UI Framework Support

- **Primary**: SwiftUI only (iOS 16+, macOS 14+, visionOS 1+)
- **No UIKit support** - Pure SwiftUI implementation
- **Availability**: Use `#available` checks for platform-specific features

### Concurrency Model

- **Primary**: Swift Concurrency (`async`/`await`)
- **State Management**: `@Published`, `@StateObject`, `@ObservableObject`
- **Threading**: `@MainActor` for UI updates and ViewModels

### Dependency Injection

- **Protocol-based DI**: ViewModels and UseCases depend on protocol abstractions
- **Constructor Injection**: Dependencies passed via initializers
- **Example**:
  ```swift
  protocol StartTOTPEnrollmentUseCase {
      func execute() async throws -> TOTPEnrollmentChallenge
  }

  @MainActor
  class TOTPPushQRCodeViewModel: ObservableObject {
      private let startTOTPUseCase: StartTOTPEnrollmentUseCase

      init(startTOTPUseCase: StartTOTPEnrollmentUseCase) {
          self.startTOTPUseCase = startTOTPUseCase
      }
  }
  ```

### Theming & Styling

- **Native SwiftUI styling**: Use built-in SwiftUI modifiers
- **Dynamic Type**: Support for accessibility text sizes
- **Dark Mode**: Full support for appearance switching
- **Platform-aware**: Adapts to iOS, macOS, and visionOS design patterns

## Development Guidelines

### Code Style

- **Language**: Swift 6.0+
- **Formatting**: SwiftLint + SwiftFormat rules (if configured)
- **Documentation**: DocC-style documentation (`///`) for public APIs
- **Naming Conventions**:
  - ViewModels: `[Component]ViewModel`
  - Views: `[Component]View` or `[Component]Screen`
  - UseCases: `[Action][Entity]UseCase` (e.g., `StartTOTPEnrollmentUseCase`)

### Component Design Principles

1. **Single Responsibility**: Each component handles one MFA factor type
2. **Composability**: Components can be nested and combined
3. **Accessibility**: Full VoiceOver and Dynamic Type support
4. **Security**: Secure handling of OTP codes, tokens, and recovery codes
5. **Cross-Platform**: Works seamlessly on iOS, macOS, and visionOS

### ViewModel Guidelines

```swift
@MainActor
final class EmailPhoneEnrollmentViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var state: EnrollmentState = .idle
    @Published var phoneNumber: String = ""
    @Published var selectedCountryCode: CountryCode = .default

    // MARK: - Dependencies
    private let startPhoneUseCase: StartPhoneEnrollmentUseCase
    private let confirmPhoneUseCase: ConfirmPhoneEnrollmentUseCase

    // MARK: - Initialization
    init(startPhoneUseCase: StartPhoneEnrollmentUseCase,
         confirmPhoneUseCase: ConfirmPhoneEnrollmentUseCase) {
        self.startPhoneUseCase = startPhoneUseCase
        self.confirmPhoneUseCase = confirmPhoneUseCase
    }

    // MARK: - Public Methods
    func startEnrollment() async {
        state = .loading
        do {
            let fullPhoneNumber = selectedCountryCode.dialCode + phoneNumber
            try await startPhoneUseCase.execute(phoneNumber: fullPhoneNumber)
            state = .otpSent
        } catch {
            state = .error(Auth0UIComponentError.from(error))
        }
    }

    func confirmEnrollment(otpCode: String) async {
        state = .confirming
        do {
            try await confirmPhoneUseCase.execute(otpCode: otpCode)
            state = .completed
        } catch {
            state = .error(Auth0UIComponentError.from(error))
        }
    }
}

// MARK: - Enrollment State
extension EmailPhoneEnrollmentViewModel {
    enum EnrollmentState: Equatable {
        case idle
        case loading
        case otpSent
        case confirming
        case completed
        case error(Auth0UIComponentError)

        static func == (lhs: EnrollmentState, rhs: EnrollmentState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading),
                 (.otpSent, .otpSent), (.confirming, .confirming),
                 (.completed, .completed):
                return true
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }
}
```

### View Guidelines

```swift
struct EmailPhoneEnrollmentView: View {
    @StateObject private var viewModel: EmailPhoneEnrollmentViewModel

    init(viewModel: @autoclosure @escaping () -> EmailPhoneEnrollmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        content
            .navigationTitle("Phone Verification")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            phoneNumberInput
        case .otpSent, .confirming:
            otpInput
        case .completed:
            completionView
        case .error(let error):
            ErrorScreen(error: error, retry: { await viewModel.startEnrollment() })
        }
    }

    private var phoneNumberInput: some View {
        VStack {
            CountryPickerView(selectedCountry: $viewModel.selectedCountryCode)
            TextField("Phone Number", text: $viewModel.phoneNumber)
                .keyboardType(.phonePad)

            Button("Send Code") {
                Task {
                    await viewModel.startEnrollment()
                }
            }
            .disabled(viewModel.phoneNumber.isEmpty)
        }
        .padding()
    }

    private var otpInput: some View {
        VStack {
            Text("Enter the code sent to your phone")
            OTPTextField { otpCode in
                Task {
                    await viewModel.confirmEnrollment(otpCode: otpCode)
                }
            }
        }
    }

    private var completionView: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 60))
            Text("Phone verification successful!")
        }
    }
}
```

### Testing Requirements

- **Unit Tests**: XCTest for ViewModels and UseCases
- **Mock Dependencies**: Protocol-based mocks for TokenProvider and UseCases
- **Coverage Goals**: 80%+ for business logic
- **Security Testing**: Verify sensitive data handling

```swift
@MainActor
final class EmailPhoneEnrollmentViewModelTests: XCTestCase {
    var sut: EmailPhoneEnrollmentViewModel!
    var mockStartUseCase: MockStartPhoneEnrollmentUseCase!
    var mockConfirmUseCase: MockConfirmPhoneEnrollmentUseCase!

    override func setUp() {
        super.setUp()
        mockStartUseCase = MockStartPhoneEnrollmentUseCase()
        mockConfirmUseCase = MockConfirmPhoneEnrollmentUseCase()
        sut = EmailPhoneEnrollmentViewModel(
            startPhoneUseCase: mockStartUseCase,
            confirmPhoneUseCase: mockConfirmUseCase
        )
    }

    func testStartEnrollmentSuccess() async {
        // Given
        mockStartUseCase.result = .success(())
        sut.phoneNumber = "1234567890"

        // When
        await sut.startEnrollment()

        // Then
        XCTAssertEqual(sut.state, .otpSent)
        XCTAssertEqual(mockStartUseCase.capturedPhoneNumber, "+11234567890")
    }

    func testStartEnrollmentFailure() async {
        // Given
        mockStartUseCase.result = .failure(Auth0UIComponentError.networkError)
        sut.phoneNumber = "1234567890"

        // When
        await sut.startEnrollment()

        // Then
        XCTAssertEqual(sut.state, .error(.networkError))
    }

    func testConfirmEnrollmentSuccess() async {
        // Given
        mockConfirmUseCase.result = .success(())
        sut.state = .otpSent

        // When
        await sut.confirmEnrollment(otpCode: "123456")

        // Then
        XCTAssertEqual(sut.state, .completed)
    }
}
```

## Build & Testing Commands

```bash
# Install Carthage dependencies (required for development)
carthage bootstrap --use-xcframeworks

# Build with Xcode
xcodebuild -project Auth0UIComponents.xcodeproj -scheme Auth0UIComponents build

# Run Tests
xcodebuild test -project Auth0UIComponents.xcodeproj -scheme Auth0UIComponents

# Or use Swift Package Manager
swift build
swift test

# Generate Documentation (if configured)
swift package generate-documentation

# Run SwiftLint (if configured)
swiftlint lint

# Run SwiftFormat (if configured)
swiftformat .
```

## MFA Components

### Available Enrollment Flows

1. **MyAccountAuthMethodsView** - Main entry point
   - Lists all enrolled factors
   - Navigate to enrollment screens
   - Delete existing factors
   - **ViewModels**: `MyAccountAuthMethodsViewModel`, `MyAccountAuthMethodViewModel`
   - **UseCases**: `GetAuthMethodsUseCase`, `GetFactorsUseCase`

2. **TOTPPushQRCodeView** - TOTP/Push enrollment
   - Display QR code for authenticator apps
   - Handle push notification setup
   - OTP verification
   - **ViewModels**: `TOTPPushQRCodeViewModel`, `OTPViewModel`
   - **UseCases**: `StartTOTPEnrollmentUseCase`, `ConfirmTOTPEnrollmentUseCase`, `StartPushEnrollmentUseCase`, `ConfirmPushEnrollmentUseCase`

3. **EmailPhoneEnrollmentView** - SMS/Email OTP
   - Country code picker for phone numbers
   - Email/phone input
   - OTP code verification
   - **ViewModel**: `EmailPhoneEnrollmentViewModel`
   - **UseCases**: `StartEmailEnrollmentUseCase`, `ConfirmEmailEnrollmentUseCase`, `StartPhoneEnrollmentUseCase`, `ConfirmPhoneEnrollmentUseCase`

4. **RecoveryCodeEnrollmentView** - Backup codes
   - Generate recovery codes
   - Display for user to save
   - Confirm enrollment
   - **ViewModel**: `RecoveryCodeEnrollmentViewModel`
   - **UseCases**: `StartRecoveryCodeEnrollmentUseCase`, `ConfirmRecoveryCodeEnrollmentUseCase`

5. **SavedAuthenticatorsScreen** - Factor management
   - View all enrolled factors
   - Delete factors
   - **ViewModel**: `SavedAuthenticatorsScreenViewModel`
   - **UseCases**: `DeleteAuthMethodUseCase`

### Core Utilities

Reusable components in `Core/Utils/`:
- **OTPTextField** - Multi-digit OTP input with auto-focus
- **CountryPickerView** - Country code selection for SMS
- **ErrorScreen** - Standardized error display with retry
- **Toast** - Transient notifications for success/info messages
- **NavigationStore** - Navigation state management
- **Auth0UIComponentError** - Unified error types

## Security Guidelines

When working with authentication components:

### Sensitive Data Handling

- **Never log tokens or OTP codes** - Even in debug builds
- **Use Keychain** - Leverage `SimpleKeychain` for credential storage
- **Clear sensitive state** - Wipe OTP codes from memory after use
- **Screenshot protection** - Consider security for recovery codes display
- **Secure text entry** - Use appropriate secure fields for OTP input

### Token Management

- **Always use TokenProvider** - Never hardcode tokens
- **Token refresh** - Handle expired tokens gracefully
- **Audience validation** - Ensure correct audience for My Account APIs (`/me/` endpoint)
- **Scope requirements** - Use appropriate scopes (`enroll:authenticators`, `remove:authenticators`)

### Error Handling

- **Auth0 errors** - Use `Auth0UIComponentError` for consistent error types
- **Network errors** - Handle timeouts and connectivity issues
- **User-friendly messages** - Don't expose internal error details
- **Step-up flow** - Handle MFA-required errors by triggering Universal Login
- **Retry logic** - Allow users to retry failed operations

### Testing with Security

- **Mock credentials** - Use `MockTokenProvider` in tests
- **Never commit secrets** - Keep `Auth0.plist` out of version control (add to `.gitignore`)
- **Test error paths** - Verify proper handling of auth failures
- **Security test cases** - Test token expiration, invalid credentials, etc.

## Accessibility Guidelines

- **VoiceOver Labels**: All interactive elements have descriptive labels
- **Dynamic Type**: All text scales with user preferences
- **Contrast Ratios**: WCAG AA minimum for all text and interactive elements
- **Focus Management**: Logical VoiceOver and keyboard navigation order
- **Testing**: Run with Accessibility Inspector on all platforms
- **Platform-specific**: Respect platform conventions (iOS, macOS, visionOS)

## Common Pitfalls

- **State Management**: Avoid `@State` in ViewModels; use `@Published`
- **Memory Leaks**: Beware of strong reference cycles in closures (use `[weak self]`)
- **Main Thread**: Always update UI on `@MainActor`
- **Preview Crashes**: Provide mock dependencies in SwiftUI previews
- **Over-abstraction**: Don't create layers without clear benefit
- **Platform differences**: Test on all supported platforms (iOS, macOS, visionOS)
- **Token expiration**: Always handle token refresh in TokenProvider
- **Navigation state**: Use NavigationStore for coordinated multi-screen flows

## AI Agent Best Practices

When assisting with this codebase:

1. **Understand Auth0 Context**: This is not a generic UI SDK - all components integrate with Auth0 My Account APIs
2. **Follow MVVM + Clean Architecture**: Separate UseCases (Domain) from ViewModels (Presentation)
3. **Use Swift Concurrency**: `async`/`await` for all API calls, `@MainActor` for UI updates
4. **Protocol-First DI**: Define protocols before implementations, use constructor injection
5. **Security Awareness**: Never log sensitive data (tokens, OTP codes, recovery codes)
6. **TokenProvider Pattern**: Always use `TokenProvider` protocol for API credentials
7. **Error Handling**: Use `Auth0UIComponentError` for consistent error types
8. **Multi-Platform**: Consider iOS, macOS, and visionOS when making changes
9. **Universal Login**: Understand step-up authentication flows
10. **Documentation**: Include usage examples and platform-specific considerations
11. **Testability**: Design for dependency injection and unit testing

### Common MFA Implementation Patterns

- **Two-phase enrollment**: Start (get challenge) → Confirm (verify response)
- **State machine**: Use enum-based states (idle → loading → success/error)
- **Navigation**: Use `NavigationStore` for coordinated flows
- **Validation**: Validate input (phone numbers, OTP codes) before API calls
- **User feedback**: Use `Toast` for success messages, `ErrorScreen` for failures
- **Platform conventions**: Follow iOS/macOS/visionOS design guidelines

## Example Workflows

### Adding a New MFA Factor Type

Let's say you need to add support for a new MFA factor type (e.g., WebAuthn):

```swift
// 1. Define Domain Use Cases
protocol StartWebAuthnEnrollmentUseCase {
    func execute() async throws -> WebAuthnChallenge
}

protocol ConfirmWebAuthnEnrollmentUseCase {
    func execute(credentialId: String, attestation: Data) async throws
}

// 2. Implement Use Cases (calling Auth0 My Account APIs)
final class DefaultStartWebAuthnEnrollmentUseCase: StartWebAuthnEnrollmentUseCase {
    private let tokenProvider: TokenProvider
    private let session: URLSession
    private let domain: String

    init(tokenProvider: TokenProvider,
         session: URLSession = .shared,
         domain: String) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.domain = domain
    }

    func execute() async throws -> WebAuthnChallenge {
        // Get API credentials via TokenProvider
        let credentials = try await tokenProvider.fetchAPICredentials(
            audience: "https://\(domain)/me/",
            scope: "enroll:authenticators"
        )

        // Make API call to Auth0 My Account API
        var request = URLRequest(url: URL(string: "https://\(domain)/me/authenticators/webauthn")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw Auth0UIComponentError.apiError
        }

        // Parse and return WebAuthnChallenge
        let decoder = JSONDecoder()
        return try decoder.decode(WebAuthnChallenge.self, from: data)
    }
}

// 3. Create ViewModel
@MainActor
final class WebAuthnEnrollmentViewModel: ObservableObject {
    @Published private(set) var state: EnrollmentState = .idle
    @Published private(set) var challenge: WebAuthnChallenge?

    private let startUseCase: StartWebAuthnEnrollmentUseCase
    private let confirmUseCase: ConfirmWebAuthnEnrollmentUseCase

    init(startUseCase: StartWebAuthnEnrollmentUseCase,
         confirmUseCase: ConfirmWebAuthnEnrollmentUseCase) {
        self.startUseCase = startUseCase
        self.confirmUseCase = confirmUseCase
    }

    func startEnrollment() async {
        state = .loading
        do {
            challenge = try await startUseCase.execute()
            state = .challengeReceived
        } catch {
            state = .error(Auth0UIComponentError.from(error))
        }
    }

    func confirmEnrollment(credentialId: String, attestation: Data) async {
        state = .confirming
        do {
            try await confirmUseCase.execute(credentialId: credentialId, attestation: attestation)
            state = .completed
        } catch {
            state = .error(Auth0UIComponentError.from(error))
        }
    }
}

// MARK: - Enrollment State
extension WebAuthnEnrollmentViewModel {
    enum EnrollmentState: Equatable {
        case idle
        case loading
        case challengeReceived
        case confirming
        case completed
        case error(Auth0UIComponentError)

        static func == (lhs: EnrollmentState, rhs: EnrollmentState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading),
                 (.challengeReceived, .challengeReceived),
                 (.confirming, .confirming), (.completed, .completed):
                return true
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }
}

// 4. Create SwiftUI View
struct WebAuthnEnrollmentView: View {
    @StateObject private var viewModel: WebAuthnEnrollmentViewModel

    init(viewModel: @autoclosure @escaping () -> WebAuthnEnrollmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Starting WebAuthn enrollment...")
            case .challengeReceived:
                webAuthnPrompt
            case .confirming:
                ProgressView("Confirming enrollment...")
            case .completed:
                completionView
            case .error(let error):
                ErrorScreen(error: error, retry: {
                    await viewModel.startEnrollment()
                })
            }
        }
        .task {
            await viewModel.startEnrollment()
        }
        .navigationTitle("WebAuthn Setup")
    }

    private var webAuthnPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Touch your security key")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Follow your browser's prompts to register your security key")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("WebAuthn enrolled successfully")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

// 5. Add Unit Tests
@MainActor
final class WebAuthnEnrollmentViewModelTests: XCTestCase {
    var sut: WebAuthnEnrollmentViewModel!
    var mockStartUseCase: MockStartWebAuthnEnrollmentUseCase!
    var mockConfirmUseCase: MockConfirmWebAuthnEnrollmentUseCase!

    override func setUp() {
        super.setUp()
        mockStartUseCase = MockStartWebAuthnEnrollmentUseCase()
        mockConfirmUseCase = MockConfirmWebAuthnEnrollmentUseCase()
        sut = WebAuthnEnrollmentViewModel(
            startUseCase: mockStartUseCase,
            confirmUseCase: mockConfirmUseCase
        )
    }

    override func tearDown() {
        sut = nil
        mockStartUseCase = nil
        mockConfirmUseCase = nil
        super.tearDown()
    }

    func testStartEnrollmentSuccess() async {
        // Given
        let challenge = WebAuthnChallenge(challenge: "test-challenge")
        mockStartUseCase.result = .success(challenge)

        // When
        await sut.startEnrollment()

        // Then
        XCTAssertEqual(sut.state, .challengeReceived)
        XCTAssertEqual(sut.challenge, challenge)
    }

    func testStartEnrollmentFailure() async {
        // Given
        mockStartUseCase.result = .failure(Auth0UIComponentError.networkError)

        // When
        await sut.startEnrollment()

        // Then
        if case .error(let error) = sut.state {
            XCTAssertEqual(error, .networkError)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testConfirmEnrollmentSuccess() async {
        // Given
        mockConfirmUseCase.result = .success(())
        sut.state = .challengeReceived

        // When
        await sut.confirmEnrollment(credentialId: "test-id", attestation: Data())

        // Then
        XCTAssertEqual(sut.state, .completed)
    }

    func testConfirmEnrollmentFailure() async {
        // Given
        mockConfirmUseCase.result = .failure(Auth0UIComponentError.invalidCredentials)
        sut.state = .challengeReceived

        // When
        await sut.confirmEnrollment(credentialId: "test-id", attestation: Data())

        // Then
        if case .error(let error) = sut.state {
            XCTAssertEqual(error, .invalidCredentials)
        } else {
            XCTFail("Expected error state")
        }
    }
}

// 6. Create Mock for Testing
final class MockStartWebAuthnEnrollmentUseCase: StartWebAuthnEnrollmentUseCase {
    var result: Result<WebAuthnChallenge, Error>!
    var executeCallCount = 0

    func execute() async throws -> WebAuthnChallenge {
        executeCallCount += 1
        return try result.get()
    }
}
```

### Integrating Components in Your App

```swift
import SwiftUI
import Auth0UIComponents

struct AccountSettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Security") {
                    NavigationLink(destination: MyAccountAuthMethodsView()) {
                        Label("Authentication Methods", systemImage: "lock.shield")
                    }
                }

                Section("Privacy") {
                    NavigationLink(destination: Text("Privacy Settings")) {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("Account Settings")
        }
    }
}
```

The `MyAccountAuthMethodsView` provides the complete MFA management experience:
- Lists all enrolled factors
- Allows enrollment in new factors (TOTP, Push, SMS, Email, Recovery Codes)
- Enables deletion of factors
- Handles errors and step-up authentication automatically
- Works seamlessly across iOS, macOS, and visionOS

### Implementing Custom TokenProvider

```swift
import Auth0
import Auth0UIComponents

final class MyTokenProvider: TokenProvider {
    private let credentialsManager: CredentialsManager

    init(credentialsManager: CredentialsManager) {
        self.credentialsManager = credentialsManager
    }

    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        return try await withCheckedThrowingContinuation { continuation in
            credentialsManager.credentials(
                withScope: scope,
                minTTL: 60
            ) { result in
                switch result {
                case .success(let credentials):
                    let apiCredentials = APICredentials(
                        accessToken: credentials.accessToken,
                        tokenType: credentials.tokenType ?? "Bearer"
                    )
                    continuation.resume(returning: apiCredentials)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// Usage in app initialization
@main
struct MyApp: App {
    let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    init() {
        let tokenProvider = MyTokenProvider(credentialsManager: credentialsManager)
        Auth0UIComponentsSDKInitializer.initialize(tokenProvider: tokenProvider)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Support & Resources

- **Sample App**: See `AppUIComponents` target for working examples
- **Auth0 My Account API**: [Documentation](https://auth0.com/docs/api/my-account)
- **Auth0.swift SDK**: [GitHub Repository](https://github.com/auth0/Auth0.swift)
- **Issue Tracker**: Report bugs and request features
- **Security Issues**: Use [Responsible Disclosure Program](https://auth0.com/responsible-disclosure-policy)

---

*This document should be updated as the SDK evolves. Last updated: 2025-12-23*
