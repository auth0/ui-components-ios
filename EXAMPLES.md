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

> **Note:** Embedded Login is in beta and requires **Auth0.swift `4.0.0-beta.1` or later 4.x**, the first release with the Embedded Authorization MFA APIs that Guardian push uses. Your tenant must have Embedded Login enabled, with Email OTP on the connection you pass in.

### Display the Embedded Login View

`EmbeddedLoginView` runs the full native sign-in flow inside your app: email entry, then the one-time code, then Guardian push when the tenant asks for a second factor. It reads `ClientId` and `Domain` from `Auth0.plist`, stores the credentials in the Keychain, and then calls `onAuthenticated` on the main actor:

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

### Guardian Push as a Second Factor

When the tenant's MFA policy asks for a second factor after the email code, `EmbeddedLoginView` sends a push to the user's Guardian app and waits for approval. With several Guardian devices, the user picks one first.

- **Approved:** the credentials are saved and `onAuthenticated` fires.
- **Denied, expired, session ended, or no Guardian device on offer:** a terminal screen with **Sign in again**, which starts a new sign-in with the email filled in.
- **No connection:** short outages are absorbed silently; after that, **Try again** resumes where it failed, without sending a second push.
- **Back:** with several devices, returns to the device list while the request can still be approved; otherwise to email entry.

Other second factors aren't supported in this flow yet.

The push screen is also available on its own, over the same `EmbeddedAuth` instance that ran the first factor. Take the devices from the `insufficient_authorization` answer to the first factor, and store the credentials yourself once the user approves:

```swift
import Auth0
import Auth0UniversalComponents
import SwiftUI

// After the first factor: the tenant wants a second one.
do {
    let credentials = try await auth.verifyOtp(code, type: .oob).start()
} catch let error as EmbeddedAuthError {
    if case let .insufficientAuthorization(.none, nextActions) = error.reason {
        // Show PushStep(auth: auth, nextActions: nextActions) { ... }
    }
}

struct PushStep: View {
    @StateObject private var controller: GuardianPushApprovalController<Credentials>
    private let onSignInAgain: () -> Void

    init(auth: EmbeddedAuth, nextActions: [NextAction],
         onSignedIn: @escaping (Credentials) -> Void, onSignInAgain: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: GuardianPushApprovalController(
            client: EmbeddedAuthGuardianPushClient(auth: auth),
            devices: EmbeddedAuthGuardianPushClient.devices(in: nextActions),
            onApproved: onSignedIn // Called once, on the main actor. Store the credentials here.
        ))
        self.onSignInAgain = onSignInAgain
    }

    var body: some View {
        GuardianPushApprovalView(controller: controller, onSignInAgain: onSignInAgain)
    }
}
```

- **Your own backend:** conform to `GuardianPushClient`, or wrap closures in `AnyGuardianPushClient(sendPush:checkApproval:)`.
- **Your own state:** `GuardianPushView(state:actions:)` renders a `GuardianPushApprovalState` from plain values. Its screens (`GuardianPushDevicePickerView`, `GuardianPushWaitingView`, `GuardianPushOutcomeView`, `GuardianPushApprovedView`) and `GuardianPushDeviceRow` can also be used on their own.
- **Polling:** pass a `GuardianPushPollingPolicy` to change the interval bounds or the network failures tolerated.

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
- **While a request is in flight,** Back and **Edit** are disabled and repeated submits are ignored. This stops a sign-in from finishing after the screen has been dismissed. The Guardian push screen is the exception: Back stops checking at once. An approval already on its way still signs the user in, and Back is ignored until it arrives.
- **Email entry keeps the email** when the user comes back to it: Back from code entry or push, **Try again**, or **Sign in again**.
- **Guardian push checks right away** when the app returns to the foreground, so approving on the same phone signs in without waiting for the next check.
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
