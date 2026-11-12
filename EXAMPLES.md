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

> **Note:** Embedded Login is in beta and requires **Auth0.swift `4.0.0-beta.1` or later 4.x**, the first release with the Embedded Authorization MFA APIs that Guardian push, phone codes and recovery codes use. Your tenant must have Embedded Login enabled, with Email OTP, SMS OTP or both on the connection you pass in.

### Display the Embedded Login View

`EmbeddedLoginView` runs the full native sign-in flow inside your app: email or phone number entry, then the one-time code (sent by email or text message), then multi-factor authentication (Guardian push, a code by text message or call, or a recovery code) when the tenant's policy asks for more. It reads `ClientId` and `Domain` from `Auth0.plist`. The SDK stores nothing: when the user is signed in it hands the credentials to `onAuthenticated`, once, on the main actor, and your app keeps them where it keeps its session:

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

`onAuthenticated` runs once, as soon as the user is signed in, and after any multi-factor step. If it throws (for example, the Keychain write fails), the user sees an error screen, and **Try again** restarts from the screen where the email or phone number was entered, because the code has already been used. Call `clear()` before `store` when you replace an earlier session: Auth0.swift keeps the previous session's pinned expiry until `clear()`, so a new sign-in could otherwise be judged expired. The credentials are yours, so never log them.

### Sign in with a Phone Number

When the connection offers SMS OTP, `EmbeddedLoginView` signs users in with a code sent by text message. Nothing changes in your code: the screens follow what the tenant offers.

- **Email and phone offered:** the first screen asks for whichever the tenant lists first, with **Continue with Phone** (or **Continue with Email**) below an **OR** divider. That button opens the other method's own screen, and Back returns to the first one.
- **Only one offered:** the first screen asks for just that one.
- **The phone field** starts on the device's country (else the United States), with a picker for the rest. Numbers are formatted as they're typed where a country has a format (US: `(423)353-0900`), checked on the device ("Please enter a valid phone number."), and sent in E.164 form (`+14233530900`).
- **The code screen** shows the number as the server masked it (`From (4**)***-*900`), with **Edit** to change it.
- **An expired texted code** stays on the code screen: **Verify** is disabled and **Resend Code** works at once. An expired email code still shows the full-screen error.

Codes are sent by text message only; a number that can only take voice calls gets "We couldn't send your code." A registered phone can also be a multi-factor step; see below.

### Multi-Factor Authentication

When the tenant's MFA policy asks for more than the one-time code, `EmbeddedLoginView` moves into MFA in place. MFA is a separate engine, whose decisions are pure logic with no UI, with its own screens, so the login only hands over and takes the result back. It runs Guardian push, SMS (a code texted to a registered phone), voice (a code read out in a call to it), email (a code sent to a registered address) and a recovery code. With more than one on offer (several devices, several phones, a phone that takes both texts and calls, or several kinds) the user picks one from a list first. Push is listed first, because an approval on a registered device can't be phished and a phone code can; a text comes before a call, and the recovery code is last. Other factors aren't supported in this flow yet.

- **Approved, or the right code:** the credentials go to `onAuthenticated`. If the policy asks for another factor, the list returns with **One more step**.
- **SMS and voice:** the code is texted, or the call is made, as soon as the factor starts. The list and the code screen show the number as the server masked it, with every hidden digit as a small, top-aligned `*` (also when the server hides digits with `X`). A wrong code stays on the screen with "Invalid Code. Please double check the code sent to your phone."; **Resend Code** sends a new one the same way after a 60 second wait, and that wait holds if the user leaves with **Verify another way** and picks the same phone again: the code that was sent is shown again instead of a second one, unless a push or another code went out in between, which replaces it. A code that timed out stays on the screen with **Verify** off and **Resend Code** open at once. A dropped connection while checking or resending a code, or a resend the server refuses, shows a message and keeps the screen, because the code already on the phone still works. Too many wrong codes ends the flow. A phone is offered once for each way it can take a code.
- **Email:** the code is emailed as soon as the factor starts. The list and the code screen show the address as the server masked it, and it works like the SMS and voice codes: a wrong code stays on the screen with "Invalid Code. Please double check the code sent to your email.", **Resend Code** sends a new one after a 60 second wait that holds if the user leaves with **Verify another way** and picks the same address again, a code that timed out stays with **Verify** off, a dropped connection keeps the screen, and too many wrong codes ends the flow. An address the sign-in's own email code already used is listed too when the tenant offers it: whether that counts as another factor is the tenant's policy.
- **Recovery code:** the field is empty when the factor starts; nothing is sent until the user types or pastes a code and taps **Continue** (the eye shows what was typed). Before it is sent the code is cleaned: invisible characters that come with pasted text (zero-width spaces, direction marks) and the whitespace around it are removed, while case, hyphens and inner spaces are sent as typed. A wrong code stays with "Invalid recovery code. Please check it and try again."; the message goes as soon as the field changes. Once a code is accepted it is used up, so the screen shows the new one with a copy button and a note to store it somewhere safe: a brief "Copied" bubble confirms the copy, **Continue** stays off until the user ticks "I have saved this recovery code", and then confirms it and signs the user in. On iOS and visionOS the copy stays on the device and leaves the pasteboard after two minutes; on macOS it is marked concealed for clipboard managers but is not removed. A dropped connection while checking or confirming keeps the screen; any other failure ends the flow. **Known limitation in this beta:** a check that has already gone out can't be recalled, and it uses the code up, so if the user taps **Back** while it runs, the new code is never shown. Wait for **Continue** to stop spinning before leaving.
- **Denied, expired, session ended, too many attempts or no connection:** a screen with its own message and **Start over**, which begins a new sign-in at the first screen, with what was typed there filled in.
- **Verify another way** (more than one factor on offer) returns to the list. **Back** cancels MFA and returns to the first screen; a push approved after that is discarded and never signs the user in.
- **No factor this flow can run** (e.g. only an authenticator app, or nothing enrolled): without a handler, a **Verification method not available.** screen with **Sign in again** shows. With `.onMfaError`, your app is told. Return `.handled` when it takes over and routes the user itself, or `.notHandled` when it only observes (logging), so the screen still shows.

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
        $0.phoneCodeChallenge.text.description = { number in "We texted a code to \(number)." }
        $0.phoneCodeChallenge.voice.row.title = "Phone call"
        $0.recoveryCodeChallenge.saveDescription = "This code works only once. Keep it for when you lose your device."
        $0.recoveryCodeChallenge.savedConfirmation = "I have stored this code"
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

The phone code screen is replaced the same way, with `MfaScreens(phoneCodeChallenge: .custom { BrandedCodeScreen(model: $0) })` and a `PhoneCodeChallengeModel`. It is used for texted and spoken codes alike: read `delivery` (`.text` or `.voice`) to word it. Call `submit(code)` with all `codeLength` digits; `isVerifying` and `isCodeRejected` say what to show, and `resendAvailableIn` works as for push. Also show `isCodeExpired` (the code timed out: `submit` does nothing, and `resend` works at once) and `requestError` (`.network` or `.tooManyAttempts` when a request failed but the code is still usable); the words are `phoneCodeChallenge.expiredCode`, `.noConnection` and `.tooManyRequests`. `destination` is the masked number with every hidden digit as `*`.

The email code screen is replaced the same way, with `MfaScreens(emailCodeChallenge: .custom { BrandedEmailScreen(model: $0) })` and an `EmailCodeChallengeModel`. It works like `PhoneCodeChallengeModel`, with `address` (the masked address) in place of `destination` and no `delivery`; its words are under `emailCodeChallenge`.

The recovery code screen is replaced with the general form below and a `RecoveryCodeChallengeModel`: while `newCode` is `nil` it takes a code through `submit(code)`; once it is set, show it and call `confirm()` when the user has saved it. The standard screen holds Continue back until its "I have saved this recovery code" box is ticked; a replacement decides that for itself. `isCodeRejected` and `requestError` (`.network`) say what to show, and the words are under `recoveryCodeChallenge`: the entry (`title`, `description`, `fieldLabel`, `placeholder`, `invalidCode`, `continueButton`, `verifyAnotherWay`) and the save step (`saveTitle`, `saveDescription`, `saveHelper`, `savedConfirmation`, `copied`, `copyCode`). `newCode` is the live recovery code: never log it, and don't print or dump the model or the step, because their descriptions include it.

The factor list and the error screen are replaced the same way, through `MfaScreens(authenticatorList:error:)`. The general form, `MfaScreens().replacing(.push) { (model: PushChallengeModel) in … }` (or `.replacing(.recoveryCode) { (model: RecoveryCodeChallengeModel) in … }`), works for any factor whose model type is public; chain it to replace more than one, for example `MfaScreens(pushChallenge: …).replacing(.voice) { (model: PhoneCodeChallengeModel) in … }` to replace only the voice code's screen.

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
            } else if let code = factorStep.model as? PhoneCodeChallengeModel {
                VStack {
                    Text(code.delivery == .voice ? "Calling \(code.destination)" : "Code sent to \(code.destination)")
                    // your own code entry: call code.submit(digits) with all code.codeLength digits
                    Button("Cancel") { code.cancel() }
                }
            } else if let recovery = factorStep.model as? RecoveryCodeChallengeModel {
                VStack {
                    if let newCode = recovery.newCode {                  // the code was used up: show its replacement
                        Text(newCode)                                    // never log this
                        Button("I have saved it") { recovery.confirm() } // signs the user in
                    } else {
                        // your own entry: call recovery.submit(typed); show recovery.isCodeRejected
                        if recovery.canSwitch { Button("Verify another way") { recovery.switchFactor() } }
                    }
                    Button("Cancel") { recovery.cancel() }
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

- An `MfaStep` is `.loading`, `.authenticatorList`, `.error`, or `.factor(step)` for a factor's own screen: read `step.factor` (for example `.push`, `.sms`, `.voice`, `.email` or `.recoveryCode`) and cast `step.model` to that factor's model (`PushChallengeModel`, `PhoneCodeChallengeModel` for both `.sms` and `.voice`, `EmailCodeChallengeModel` for `.email`, or `RecoveryCodeChallengeModel`). New factors add no case, so switch with `@unknown default`.
- The standard screens (`MfaAuthenticatorListScreen`, `MfaPushChallengeScreen`, `MfaPhoneCodeChallengeScreen`, `MfaEmailCodeChallengeScreen`, `MfaRecoveryCodeScreen`, `MfaErrorScreen`, `MfaLoadingScreen`) can also be used on their own with a model, to keep the look for steps you don't want to redraw.

#### Multi-step sign-in

A policy that needs several factors shows the list again for each step, headed **One more step**, all inside one MFA run, for as many steps as the server asks for. The step number is on the models (`AuthenticatorListModel.round`, `MfaFactorStep.round`). The credentials reach your app once, at the end.

#### How the pieces fit

Login, the MFA engine and each factor don't know each other's insides:

- **Login** only has a small `AdditionalStep` contract ("an additional step runs here") and never mentions MFA.
- **The MFA engine** (`MFA/Core`) knows the factor list, rounds, switching, cancel, handing over the credentials and rendering the current step. It names no factor, no login type and no Auth0 type.
- **A factor** (`MFA/Factors/Push`, `PhoneCode` and `RecoveryCode` today) is an id and rank, a session that runs it, a model and screen, its words, and a small transport protocol it defines. Adding one touches no engine file.
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

- **Recoverable errors appear inline:** an invalid code, a code that couldn't be sent, an expired texted code, or too many attempts. The user stays on the current screen; when attempts run out, they can use **Resend Code**.
- **Other failures go full screen:** network or server errors. **Try again** returns to the step that failed.
- **While a request is in flight,** Back and **Edit** are disabled and repeated submits are ignored. This stops a sign-in from finishing after the screen has been dismissed. During MFA, Back cancels it at once, and an approval already on its way is discarded.
- **Email and phone entry keep what was typed** when the user comes back to them: Back or **Edit** from code entry, Back from push, **Try again**, or **Sign in again**. A phone number comes back with its country.
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

struct CustomPhoneStep: View {
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        LoginPhoneScreen(isLoading: isLoading, errorMessage: errorMessage) { number in
            // `number` is in E.164 form, e.g. "+14233530900"
            isLoading = true
            Task {
                defer { isLoading = false }
                // text the code to `number`, and set `errorMessage` on failure
            }
        }
    }
}

struct CustomCodeStep: View {
    let sentTo: String                  // an email, or the server's masked number
    @State private var isLoading = false
    @State private var isCodeExpired = false

    var body: some View {
        LoginCodeScreen(
            subtitle: "From \(sentTo)",
            isLoading: isLoading,           // also disables "Edit" while verifying
            isCodeExpired: isCodeExpired,   // Verify off, Resend available at once
            onVerify: { code in /* verify `code` */ },
            onEdit: { /* return to email or phone entry */ },
            onResend: { /* resend the code */ }
        )
    }
}
```

The other screens and building blocks are also public and work the same way:

- **Screens:** `LoginLoadingScreen`, `LoginErrorScreen`, `LoginSuccessScreen`, `LoginNoMethodsScreen`.
- **Building blocks:** `LoginScreenHeader` (with `isEditEnabled`), `LoginInputField`, `LoginCodeField` (with `isEnabled`), `LoginPrimaryButton`, `LoginResendButton` (with `isAvailableNow`).
