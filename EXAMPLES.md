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

`EmbeddedLoginView` runs the full native sign-in flow inside your app: email entry, then the one-time code, then multi-factor authentication (Guardian push) when the tenant's policy asks for more. It reads `ClientId` and `Domain` from `Auth0.plist`. The SDK stores nothing: when the user is signed in it hands the credentials to `onAuthenticated`, once, on the main actor, and your app keeps them where it keeps its session:

```swift
import SwiftUI
import Auth0
import Auth0UniversalComponents

struct LoginView: View {
    @State private var isSignedIn = false
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    var body: some View {
        NavigationStack {
            EmbeddedLoginView(connection: "email") { credentials in
                // The SDK keeps nothing: this app decides where the credentials go.
                try? credentialsManager.clear()      // drop an earlier session's pinned expiry
                try credentialsManager.store(credentials: credentials)
                isSignedIn = true
            }
        }
        .fullScreenCover(isPresented: $isSignedIn) {
            HomeView()
        }
    }
}
```

`onAuthenticated` runs once, as soon as the user is signed in, and after any multi-factor step. If it throws (for example, the Keychain write fails), the user sees an error screen, and **Try again** restarts from email entry, because the code has already been used. Call `clear()` before `store` when you replace an earlier session: Auth0.swift keeps the previous session's pinned expiry until `clear()`, so a new sign-in could otherwise be judged expired. The credentials are yours, so never log them.

### Multi-Factor Authentication

When the tenant's MFA policy asks for more than the email code, `EmbeddedLoginView` moves into MFA in place. MFA is a separate engine, whose decisions are pure logic with no UI, with its own screens, so the login only hands over and takes the result back. Today it runs Guardian push; with several Guardian devices the user picks one from a list first. Other factors aren't supported in this flow yet.

- **Approved:** the credentials go to `onAuthenticated`. If the policy asks for another factor, the list returns with **One more step**.
- **Denied, expired, session ended, too many attempts or no connection:** a screen with its own message and **Start over**, which begins a new sign-in with the email filled in.
- **Verify another way** (several devices) returns to the list. **Back** cancels MFA and returns to email entry; a push approved after that is discarded and never signs the user in.
- **No factor this flow can run** (e.g. only an authenticator app or SMS, or nothing enrolled): without a handler, a **Verification method not available.** screen with **Sign in again** shows. With `.onMfaError`, your app is told. Return `.handled` when it takes over and routes the user itself, or `.notHandled` when it only observes (logging), so the screen still shows.

#### Fall back to Universal Login

`.onMfaError` reports every way MFA can end without signing the user in, except a cancel (the user is still in the login). The one most apps act on is `MfaError.noEligibleFactors`:

```swift
struct SignInScreen: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        EmbeddedLoginView(connection: "email") { credentials in
            try session.store(credentials)       // the flow is complete; the SDK kept nothing
        }
        .onMfaError { error -> MfaErrorHandling in
            // Log or measure the error here: that alone does not take the screen away.
            guard case .noEligibleFactors = error else { return .notHandled }   // the other endings show their own screen
            // This account has no factor the native flow can run. Universal Login supports every factor.
            Task { await session.signInWithUniversalLogin() }
            return .handled
        }
    }
}

extension SessionStore {
    /// Both sign-in paths end here: the app keeps the credentials and marks the user signed in.
    func store(_ credentials: Credentials) throws {
        try? credentialsManager.clear()
        try credentialsManager.store(credentials: credentials)
        didSignIn()
    }

    func signInWithUniversalLogin() async {
        do {
            let credentials = try await Auth0.webAuth()
                .scope("openid profile email offline_access")
                .start()
            try store(credentials)
        } catch {
            // The user closed the browser sheet: they stay on the login, which still offers Back.
        }
    }
}
```

While your app moves on, the user sees a spinner, not an error. Return `.handled` only when your app really takes over: if a handler that only logs said `.handled`, the user would be left on a spinner with no way to cancel. The answer matters only for `noEligibleFactors`; every other ending has its own screen with a way out. To react to every case, switch over `MfaError` and include `@unknown default`; later releases may add cases. See "Handling MFA errors" in the documentation for what each case means.

#### Change the words

Pass an `MfaConfiguration` to change the words, replace a screen, or draw everything yourself. `MfaMessages` is a typed tree: change only the lines you care about and the rest keep their defaults. Text that depends on a value, such as the device name, is a function. A device with no name uses `pushChallenge.descriptionUnnamed`.

```swift
let mfa = MfaConfiguration(
    messages: .default.with {
        $0.authenticatorList.headers.challengeAdditional.title = "Almost there"
        $0.pushChallenge.description = { device in "Approve the request on \(device)." }
        $0.pushChallenge.title = String(localized: "mfa.push.title")     // your own localized string
    }
)
EmbeddedLoginView(connection: "email", mfa: mfa) { credentials in try session.store(credentials) }
```

The built-in words are English, and the SDK doesn't read your app's String Catalog. To translate them, set the lines with your own `String(localized:)` values as above.

#### Replace one screen

A replaced screen only renders its model and calls its actions, so the timers, polling, cancel and switching keep working underneath.

```swift
struct BrandedPushScreen: View {
    let model: PushChallengeModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Approve on \(model.deviceName)").font(.title2)
            ProgressView()
            if model.canResend {
                Button(model.resendAvailableIn > 0 ? "Send again in \(model.resendAvailableIn)s" : "Send again") {
                    model.resend()
                }
                .disabled(model.resendAvailableIn > 0)
            }
            if model.canSwitch { Button("Use another way") { model.switchFactor() } }
            Button("Cancel", role: .cancel) { model.cancel() }
        }
    }
}

let mfa = MfaConfiguration(
    screens: MfaScreens(pushChallenge: .custom { BrandedPushScreen(model: $0) })
)
```

`canResend` says whether the server still allows another push. `resendAvailableIn` is the seconds left before it may be sent, and 0 when it can be tapped now. The flow owns that countdown, so calling `resend()` early does nothing; a replacement only has to show it (the model is published again each second while it counts down). A replacement is also responsible for its own accessibility.

The factor list and the error screen are replaced the same way, through `MfaScreens(authenticatorList:error:)`. The general form, `MfaScreens().replacing(.push) { (model: PushChallengeModel) in … }`, works for any factor whose model type is public.

#### Draw everything yourself (headless)

The flow still decides everything: which factors to offer, when to poll, when to give up, and when to hand the credentials to your app. It only publishes each step into a stream **you** create and hold, and you draw it however you like.

```swift
struct HeadlessSignIn: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var stream = MfaStepStream()                // you own the stream

    var body: some View {
        ZStack {
            EmbeddedLoginView(connection: "email",
                              mfa: MfaConfiguration(presentation: .headless(stream))) { credentials in
                try session.store(credentials)
            }
            if let step = stream.step {                              // nil = nothing to draw
                MyMfaScreens(step: step)
            }
        }
    }
}

struct MyMfaScreens: View {
    let step: MfaStep

    var body: some View {
        switch step {
        case .authenticatorList(let model):
            VStack {
                ForEach(model.rows) { row in Button(row.title) { model.select(row.id) } }
                Button("Cancel") { model.cancel() }
            }
        case .factor(let factorStep):                                // a factor's own screen: cast its model
            if let push = factorStep.model as? PushChallengeModel {
                VStack {
                    Text("Waiting on \(push.deviceName)")
                    Button("Cancel") { push.cancel() }
                }
            } else {
                ProgressView()
            }
        case .error(let model):
            Button("Start over") { model.leave() }
        case .loading:
            ProgressView()
        @unknown default:
            ProgressView()
        }
    }
}
```

- An `MfaStep` is `.loading`, `.authenticatorList`, `.error`, or `.factor(step)` for a factor's own screen: read `step.factor` (for example `.push`) and cast `step.model` to that factor's model (for example `PushChallengeModel`). New factors add no case, so switch with `@unknown default`.
- `stream.step` is `nil` when there is nothing to draw: before the flow starts, and after it ends signed in, cancelled, or with no factor to use. Your overlay goes away and the login's own screen shows.
- `stream.result` is `.signedIn` or `.ended(error)` when the flow ends, and goes back to `nil` when the next flow starts.
- The login still draws its own background and navigation bar; only the MFA steps are yours.
- The standard screens (`MfaAuthenticatorListScreen`, `MfaPushChallengeScreen`, `MfaErrorScreen`, `MfaLoadingScreen`) can also be used on their own with a model, to keep the look for steps you don't want to redraw.

#### Multi-step sign-in

A policy that needs several factors shows the list again for each step, headed **One more step**, all inside one MFA run, for as many steps as the server asks for. The step number is on the models (`AuthenticatorListModel.round`, `MfaFactorStep.round`). The credentials reach your app once, at the end.

#### How the pieces fit

Login, the MFA engine and each factor don't know each other's insides:

- **Login** only has a small `AdditionalStep` contract ("an additional step runs here") and never mentions MFA.
- **The MFA engine** (`MFA/Core`) knows the factor list, rounds, switching, cancel, handing over the credentials and rendering the current step. It names no factor, no login type and no Auth0 type.
- **A factor** (`MFA/Factors/Push` today) is an id and rank, a session that runs it, a model and screen, its words, and a small transport protocol it defines. Adding one touches no engine file.
- **`EmbeddedMfaStep`** is the only adapter that knows both sides: it reads each factor's eligible factors from the server's response and builds the factors over the sign-in.

A source-level test (`ArchitectureTests`) fails if a layer starts to mention what it must not know.

### Read the Stored Credentials

The SDK stores nothing, so you read back whatever your `onAuthenticated` closure stored. With the `CredentialsManager` from the example above:

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
- **While a request is in flight,** Back and **Edit** are disabled and repeated submits are ignored. This stops a sign-in from finishing after the screen has been dismissed. During MFA, Back cancels it at once, and an approval already on its way is discarded.
- **Email entry keeps the email** when the user comes back to it: Back from code entry or push, **Try again**, or **Sign in again**.
- **Push checks right away** when the app returns to the foreground, so approving on the same phone signs in without waiting for the next check.
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
