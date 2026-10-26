# Change Log

## Unreleased

**Added**

- **Embedded Login: Guardian push as a second factor.** When the tenant asks for a second factor after the email code, `EmbeddedLoginView` sends a Guardian push and waits for approval, with a device picker when there are several Guardian devices. No push device, a denied request, an expired request or an ended session show a terminal screen with **Sign in again**.
- **Standalone Guardian push component:** `GuardianPushApprovalController`, `GuardianPushApprovalView`, `GuardianPushView` and its building blocks, the `GuardianPushClient` protocol, `AnyGuardianPushClient`, and `EmbeddedAuthGuardianPushClient` for Auth0.swift.

**Changed**

- Embedded Login keeps the email when the user comes back to email entry: Back from code entry or Guardian push, **Try again**, or **Sign in again**.
- Embedded Login now advertises only the steps it can render (Email OTP and Guardian push) in its `authorize` capabilities.
- Requires Auth0.swift `4.0.0-beta.1` or later 4.x, the first release with the push APIs.


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
