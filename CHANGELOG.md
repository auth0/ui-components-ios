# Change Log

## Unreleased

**Added**

- **Embedded Login: multi-factor authentication (MFA).** When the tenant's policy asks for more than the email code, `EmbeddedLoginView` continues in place with MFA. Guardian push is the first factor: with several Guardian devices the user picks one from a list, and **Verify another way** returns to it. A policy that needs another factor shows the list again with **One more step**. Back cancels MFA and returns to email entry, and a push approved after that is discarded and never signs the user in. A denied, expired or ended request, too many attempts or no connection shows a screen with its own message and **Start over**. An account with no factor this flow can run shows **Verification method not available.** (`LoginAdditionalStepUnavailableScreen`), or, with `.onMfaError`, your app is told and can fall back to Universal Login.
- **A separate MFA engine.** MFA runs on its own engine whose decisions are pure logic with no UI, so the login no longer drives push itself. The engine is factor-agnostic: a factor is an id, a session, a model and screen, its own words and a transport protocol, so adding one needs no change to the engine or to the login. The login only has a small `AdditionalStep` contract ("an additional step runs here") and knows nothing about MFA. New public API: `MfaConfiguration` (`MfaMessages` words, extended per factor; `MfaScreens` with per-factor replacement; `MfaPresentation`, including `.headless(MfaStepStream)`), `MfaStep` (`.loading`, `.authenticatorList`, `.factor`, `.error`), `PushChallengeModel`, the standard screens (`MfaAuthenticatorListScreen`, `MfaPushChallengeScreen`, `MfaErrorScreen`, `MfaLoadingScreen`), the typed `MfaError`, `MfaFactorID`, `EmbeddedLoginView(connection:mfa:onAuthenticated:)` and `.onMfaError { }`. Existing `EmbeddedLoginView` call sites compile unchanged.
- **Multi-step sign-in.** Every factor a policy needs runs inside one MFA session, and the credentials are stored once, at the end. `MfaConfiguration.maximumRounds` (default 3) limits the steps; `AuthenticatorListModel.round` and `MfaFactorStep.round` number them.
- **Documentation.** A DocC article set for multi-factor authentication (getting started, errors, customizing, headless, multi-step, how it is structured, adding a factor), with diagrams that follow light and dark mode, and doc comments on every public MFA symbol.

**Changed**

- Embedded Login keeps the email when the user comes back to email entry: Back from code entry or MFA, **Try again**, **Start over** or **Sign in again**.
- Embedded Login now advertises only the steps it can render (Email OTP and Guardian push) in its `authorize` capabilities.
- Requires Auth0.swift `4.0.0-beta.1` or later 4.x, the first release with the push APIs.
- Error screens never show the SDK's internal codes (e.g. `too_many_attempts`); rate limits, IP blocks and consent errors get their own copy.
- The **Resend Code** countdowns keep time while the screen redraws, and announce the time left to VoiceOver.


## [1.0.0-beta.1](https://github.com/auth0/ui-components-ios/tree/1.0.0-beta.1) (2026-10-14)
[Full Changelog](https://github.com/auth0/ui-components-ios/compare/1.0.0-beta.0...1.0.0-beta.1)

**⚠️ Breaking**

> Apps that depend on `from: "1.0.0-beta.0"` will pick up this release on their next package update. To stay on Auth0.swift 2.x, pin `exact: "1.0.0-beta.0"` until you're ready to migrate.

- **Auth0.swift moves from `2.x` (GA) to `4.0.0-beta.0` (pre-release).** SPM now requires `from: "4.0.0-beta.0"`, and Carthage pins `"4.0.0-beta.0"` exactly. JWTDecode.swift moves to `4.0.0`. Apps that depend on Auth0.swift 2.x or 3.x directly must move to 4.0.0-beta.0 or later, and follow the Auth0.swift migration guides.
- **`TokenProvider` implementations** compile against the Auth0.swift 4.0 `Credentials` and `APICredentials` types. `CredentialsManager.store(...)` now throws, and `APICredentials` uses `expiresAt`. Web Auth `clearSession` is now `logout`.
- **Carthage users** must rebuild every platform slice: `carthage update --use-xcframeworks --platform iOS,macOS,visionOS`.

**Added**

- **Embedded Login (beta)** — `EmbeddedLoginView` runs a native, in-app sign-in with Email OTP (email entry, then the one-time code). It stores the credentials in the Keychain and calls `onAuthenticated`. MFA step-up isn't supported in this flow yet: a tenant that asks for a second factor during embedded sign-in gets the error screen.
- **`Router.replaceTop(with:)`** — replaces the top destination in a single path change. Use it instead of `pop()` followed by `navigate(to:)`, which `NavigationStack` can turn into a double push.
- **Skeleton shimmer loading** — Card screens (`MyAccountAuthMethodsView`, `SavedAuthenticatorsView`) now show animated, theme-aware skeleton placeholders while data loads, replacing the previous spinner. Supports light/dark mode and respects Reduce Motion.
- Embedded Login Implementation: Initial Discovery + Login via Email OTP factor [\#71](https://github.com/auth0/ui-components-ios/pull/71) ([Sudhanshu96](https://github.com/Sudhanshu96))

## [1.0.0-beta.0](https://github.com/auth0/ui-components-ios/tree/1.0.0-beta.0) (2026-06-05)

**Auth0UniversalComponents iOS — Beta Release**

**Features**

- **Passkey Management**  — Enroll and manage passkeys for your account
- **MFA factor management** - Enroll / list / remove for TOTP, Push, SMS OTP, Email OTP, Recovery Codes
- **Guardian MFA Authenticator** — Multi-factor authentication with OTP code generation and copy functionality
- **Step-up Authentication** — Prompt users for additional verification when accessing sensitive actions
- **Theming** — Customizable theming system to match your app's brand
