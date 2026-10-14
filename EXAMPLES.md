# Examples

This document provides code examples for using the Auth0 UI Components SDK.

## Table of Contents

- [Initialization](#initialization)
- [Authentication Methods Management](#authentication-methods-management)
- [Embedded Login](#embedded-login)

## Initialization

### Initialize with Auth0.plist

The simplest way to initialize the SDK is using the `Auth0.plist` configuration file and providing a token provider:

```swift
import SwiftUI
import Auth0UniversalComponents

@main
struct MyApp: App {
    init() {
        Auth0UniversalComponentsSDKInitializer.initialize(tokenProvider: YourTokenProvider())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Initialize Programmatically

You can also initialize the SDK programmatically by providing required keys and token provider:

```swift
import SwiftUI
import Auth0UniversalComponents

@main
struct MyApp: App {
    init() {
        Auth0UniversalComponentsSDKInitializer.initialize(session: URLSession = .shared,
                                                   bundle: Bundle = .main,
                                                   domain: "your-auth0-domain",
                                                   clientId: "your_client_id",
                                                   audience: "https://your-auth0-domain.auth0.com/me/",
                                                   tokenProvider: YourTokenProvider())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Token Provider Implementation

If initializing programmatically, you need to implement a token provider:

```swift
import Auth0
import Auth0UniversalComponents

struct YourTokenProvider: TokenProvider {
    func fetchCredentials() async throws -> Credentials {
        // custom logic to fetch credentials
    }

    func storeCredentials(credentials: Credentials) {
        // custom logic to store credentials
    }

    func store(apiCredentials: APICredentials, for audience: String) {
        // custom logic to store API credentials
    }

    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        // custom logic to fetch API credentials
    }
}
```

## Authentication Methods Management

### Display Authentication Methods View

Once initialized, you can present the authentication methods management view to allow users to view and manage their MFA authenticators:

```swift
import SwiftUI
import Auth0UniversalComponents

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: MyAccountAuthMethodsView()) {
                    Label("Authentication Methods", systemImage: "lock.shield")
                }
            }
            .navigationTitle("Account Settings")
        }
    }
}
```

### Using MyAccountAuthMethodsView

The `MyAccountAuthMethodsView` component allows users to:

- **View enrolled authenticators** - See all configured MFA methods including:
  - TOTP (Time-based One-Time Password) from authenticator apps
  - Push notifications
  - Email
  - SMS
  - Recovery codes
  - Passkeys (FIDO2/WebAuthn) - Requires iOS 16.6+, macOS 13.5+, visionOS 1.0+
- **Enroll in new authentication methods** - Add additional authentication factors
- **Delete authentication methods** - Remove enrolled authenticators
- **Manage recovery codes** - Generate and manage backup codes for account recovery

## Embedded Login

> **Note:** Embedded Login is in beta and requires **Auth0.swift `4.0.0-beta.0`**, which this SDK pins exactly. Your tenant must have Embedded Login enabled, with Email OTP on the connection you pass in.

### Display the Embedded Login View

`EmbeddedLoginView` runs the full native sign-in flow inside your app: email entry, the one-time code, and an optional MFA step-up. It reads `ClientId` and `Domain` from `Auth0.plist`, stores the credentials in the Keychain, and then calls `onAuthenticated` on the main actor:

```swift
import SwiftUI
import Auth0UniversalComponents

struct LoginView: View {
    @State private var isSignedIn = false

    var body: some View {
        NavigationStack {
            EmbeddedLoginView(connection: "email") {
                // Credentials are already in the Keychain at this point.
                isSignedIn = true
            }
        }
        .fullScreenCover(isPresented: $isSignedIn) {
            HomeView()
        }
    }
}
```

`onAuthenticated` fires only once the credentials are saved. If the Keychain write fails, the user sees an error screen, and **Try again** restarts from email entry, because the code has already been used.

### Read the Stored Credentials

The flow saves the credentials with the default `CredentialsManager`, so you can read them back like this:

```swift
import Auth0

let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

if credentialsManager.canRenew() {
    let credentials = try await credentialsManager.credentials()
    // Use credentials.accessToken / credentials.idToken
}
```

### Flow Behaviour

- **Recoverable errors appear inline:** an invalid code, a code that couldn't be sent, or too many attempts. The user stays on the current screen; when attempts run out, they can use **Resend Code**.
- **Other failures go full screen:** network or server errors. **Try again** returns to the step that failed.
- **While a request is in flight,** Back and **Edit** are disabled and repeated submits are ignored. This stops a sign-in from finishing after the screen has been dismissed.
- **During the initial loading screen,** Back still leaves the flow.

### Use the Screens Standalone

Each screen takes plain values and closures, so you can drive it from your own state. Pass `isLoading` while your request runs: the screens ignore taps and keyboard submits during that time.

```swift
import SwiftUI
import Auth0UniversalComponents

struct CustomEmailStep: View {
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            LoginNavigationBar(title: "Log in", isBackEnabled: !isLoading) {
                // handle back
            }
            LoginEmailScreen(isLoading: isLoading, errorMessage: errorMessage) { email in
                isLoading = true
                Task {
                    defer { isLoading = false }
                    // send the code to `email`, and set `errorMessage` on failure
                }
            }
        }
    }
}

struct CustomCodeStep: View {
    let email: String
    @State private var isLoading = false

    var body: some View {
        LoginCodeScreen(
            subtitle: "From \(email)",
            isLoading: isLoading,           // also disables "Edit" while verifying
            onVerify: { code in /* verify `code` */ },
            onEdit: { /* return to email entry */ },
            onResend: { /* resend the code */ }
        )
    }
}
```

The other screens and building blocks are also public and work the same way:

- **Screens:** `LoginLoadingScreen`, `LoginErrorScreen`, `LoginSuccessScreen`, `LoginNoMethodsScreen`.
- **Building blocks:** `LoginScreenHeader` (with `isEditEnabled`), `LoginInputField`, `LoginCodeField`, `LoginPrimaryButton`, `LoginResendButton`.
