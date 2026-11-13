# Change Log

## Unreleased

**Added**

- **Embedded Login MFA: email code as a factor.** When the tenant's policy offers a registered email address, the code is emailed and entered in place. It runs on the same engine as SMS and voice codes, so a wrong or expired code stays on the screen and **Resend Code** waits 60 seconds. New public API: `EmailCodeChallengeModel`, `MfaEmailCodeChallengeScreen`, `EmailCodeChallengeMessages` (`MfaMessages.emailCodeChallenge`), `MfaFactorID.email` and `MfaScreens(emailCodeChallenge:)`.
- **Embedded Login MFA: recovery code as a factor.** When the tenant's policy offers a recovery code, it is listed last (**Recovery code**) and takes the user to the sign-in's own entry: a title, a label, a field that hides what is typed (an eye shows it) and **Continue**. Before a code is sent it is cleaned: invisible characters that come with pasted text (zero-width spaces, direction marks) and the whitespace around it are removed, while case, hyphens and inner spaces are sent as typed. A wrong code stays on the screen with its own message, which goes as soon as the field changes. Using a code replaces it, so the new one is then shown with a copy button and a note to store it somewhere safe; a brief **Copied** bubble confirms the copy, **Continue** stays off until the user ticks **I have saved this recovery code**, and then confirms the code and signs the user in (a dropped connection leaves it on screen to confirm again). On iOS and visionOS the copy stays on this device and is taken back from the pasteboard after two minutes; on macOS it is marked concealed for clipboard managers but not removed. `LoginScreenHeader` gains `subtitleLineLimit` (default `1`; `nil` wraps a long subtitle). A request that has not gone out when the user leaves is never sent; one already on its way can't be recalled. It plugs into the MFA engine without changing it. New public API: `RecoveryCodeChallengeModel`, `MfaRecoveryCodeScreen`, `RecoveryCodeChallengeMessages` (`MfaMessages.recoveryCodeChallenge`) and `MfaFactorID.recoveryCode`. See "Multi-Factor Authentication" in `EXAMPLES.md`.

## [1.0.0-beta.3](https://github.com/auth0/ui-components-ios/tree/1.0.0-beta.3) (2026-11-06)
[Full Changelog](https://github.com/auth0/ui-components-ios/compare/1.0.0-beta.2...1.0.0-beta.3)

**Added**

- **Embedded Login: sign in with a phone number (SMS OTP).** When the connection offers SMS OTP, `EmbeddedLoginView` texts the one-time code and signs the user in with it. No code changes are needed: the screens follow what the tenant offers. With email and phone both offered, the first screen asks for whichever the tenant lists first, with **Continue with Phone** (or **Continue with Email**) below an **OR** divider, which opens the other method's own screen. The phone field starts on the device's country, formats numbers as they're typed where the country has a format (US for now), checks them on the device and sends them in E.164 form (a leading 0 written the local way, as in `07700 900123`, is dropped). The code screen shows the number as the server masked it. An expired texted code stays on the code screen with **Verify** disabled and **Resend Code** available at once. Codes go by text message only, and SMS isn't available as a multi-factor step yet. See "Sign in with a Phone Number" in `EXAMPLES.md`.
- **Embedded Login MFA: SMS and voice codes as factors.** When the tenant's policy asks for more and the user has a registered phone, the code is texted (**Text message**) or read out in a call (**Voice call**), whichever the phone takes, and checked in place. A phone that takes both is listed once for each. The list shows push first, then text, then voice. The phone's masked number is shown with every hidden digit as a small, top-aligned `*` in the list and on the code screen, as on the sign-in's own phone screen, including when the server hides digits with `X`. A wrong code stays on the screen with its own message, **Resend Code** sends a new one after a 60 second wait (owned by the flow, so replaced and headless screens get the same wait), and **Verify another way** returns to the list. Coming back to a phone that was just sent a code shows that code's screen again, with the rest of the wait, instead of sending another, unless a push or another code went out in between. A code that timed out stays on the screen with **Verify** off and **Resend Code** open at once; a dropped connection while checking or resending a code, or a refused resend, keeps the screen too, since the code on the phone still works. Too many wrong codes still ends the flow. Like push, both plug into the MFA engine without changing it, as one phone code factor run once per delivery. New public API: `PhoneCodeChallengeModel` (with `delivery`: `PhoneCodeDelivery.text` or `.voice`), `MfaPhoneCodeChallengeScreen`, `PhoneCodeChallengeMessages` (`MfaMessages.phoneCodeChallenge`, with `text` and `voice` branches, and `expiredCode`, `noConnection` and `tooManyRequests` for the cases above), `MfaFactorID.sms`, `MfaFactorID.voice`, `MfaScreens(phoneCodeChallenge:)`, and `AuthenticatorListModel.Row.systemImage` (an SF Symbol name; the **Voice call** row uses `phone`, a handset, until the design's own icon is added). See "Multi-Factor Authentication" in `EXAMPLES.md`.
- **New public API.** `LoginPhoneScreen` (the standalone phone entry screen; hands back an E.164 number). `LoginCodeScreen(isCodeExpired:)`, `LoginCodeField(isEnabled:)` and `LoginResendButton(isAvailableNow:)`. All new parameters have defaults, so existing call sites compile unchanged.
- Implemented login via Phone SMS OTP in Embedded flow [\#82](https://github.com/auth0/ui-components-ios/pull/82) ([Sudhanshu96](https://github.com/Sudhanshu96))
- MFA for SMS OTP and Voice OTP implemented [\#83](https://github.com/auth0/ui-components-ios/pull/83) ([Sudhanshu96](https://github.com/Sudhanshu96))

**Changed**

- Embedded Login now advertises the phone steps (`identifyPhone`, `challengePhone`) in its `authorize` capabilities, as well as Email OTP and Guardian push. Steps the sign-in and MFA both need are advertised once.
- Requests of one sign-in are sent one at a time across every MFA factor, not just within one: a push check still on its way when the user switches to SMS finishes before the code is texted.
- `LoginEmailScreen` disables **Continue** while its "Please enter a valid email address." error shows. A server error (such as "We couldn't send your code") leaves it enabled so the user can try again.
- The code screen greys out the digits, locks them and puts the keyboard away while a code is being verified.

**Fixed**

- The country list was missing when the SDK is installed with Swift Package Manager (`CountryCodes.json` wasn't bundled), so the country picker in phone enrollment was empty.

## [1.0.0-beta.2](https://github.com/auth0/ui-components-ios/tree/1.0.0-beta.2) (2026-11-03)
[Full Changelog](https://github.com/auth0/ui-components-ios/compare/1.0.0-beta.1...1.0.0-beta.2)

**⚠️ Breaking** (beta)

- **`EmbeddedLoginView` no longer stores the credentials.** `onAuthenticated` now receives the `Credentials` and may throw: `{ credentials in try credentialsManager.store(credentials: credentials) }`. The SDK keeps nothing, so where the credentials go is the app's decision, and the app can no longer end up with two copies, one of them in a Keychain location it never chose. It runs once, as soon as the user is signed in and after any multi-factor step. If it throws, the user sees the "couldn't save" screen and can start again. The closure has no default, so a sign-in can't complete without the app taking the credentials. Call `clear()` before `store` when replacing an earlier session, because Auth0.swift keeps the previous session's pinned expiry until then. See "Embedded Login" in `EXAMPLES.md`.

**Added**

- **Embedded Login: multi-factor authentication (MFA).** When the tenant's policy asks for more than the email code, `EmbeddedLoginView` continues in place with MFA. Guardian push is the first factor: with several Guardian devices the user picks one from a list, and **Verify another way** returns to it. A policy that needs another factor shows the list again with **One more step**. Back cancels MFA and returns to email entry, and a push approved after that is discarded and never signs the user in. A denied, expired or ended request, too many attempts or no connection shows a screen with its own message and **Start over**. An account with no factor this flow can run shows **Verification method not available.** (`LoginAdditionalStepUnavailableScreen`), or, with `.onMfaError`, your app is told and can fall back to Universal Login. The handler answers with `MfaErrorHandling`: `.handled` when your app routes the user itself, `.notHandled` when it only observes (logging), so the screen still shows and the user is never left on a spinner with no way out.
- **A separate MFA engine.** MFA runs on its own engine whose decisions are pure logic with no UI, so the login no longer drives push itself. The engine is factor-agnostic: a factor is an id, a session, a model and screen, its own words and a transport protocol, so adding one needs no change to the engine or to the login. The login only has a small `AdditionalStep` contract ("an additional step runs here") and knows nothing about MFA. New public API: `MfaConfiguration` (`MfaMessages` words, extended per factor; `MfaScreens` with per-factor replacement; `MfaPresentation`, including `.headless(MfaStepStream)`), `MfaStep` (`.loading`, `.authenticatorList`, `.factor`, `.error`), `PushChallengeModel`, the standard screens (`MfaAuthenticatorListScreen`, `MfaPushChallengeScreen`, `MfaErrorScreen`, `MfaLoadingScreen`), the typed `MfaError`, `MfaFactorID`, `EmbeddedLoginView(connection:mfa:onAuthenticated:)` and `.onMfaError { }`. Existing `EmbeddedLoginView` call sites compile unchanged.
- **Multi-step sign-in.** Every factor a policy needs runs inside one MFA session, and the credentials go to the app once, at the end. The server decides how many steps a sign-in needs and the flow follows it, with no limit of its own; `AuthenticatorListModel.round` and `MfaFactorStep.round` number the steps.
- **A resend wait that every screen gets.** The 60 second wait before a push can be resent belongs to the flow, not to the standard button. `PushChallengeModel.resendAvailableIn` counts it down, and `resend()` does nothing until it reaches 0, so replaced and headless screens are held to the same wait.
- **Documentation.** A DocC article set for multi-factor authentication (getting started, errors, customizing, headless, multi-step, how it is structured, adding a factor), with diagrams that follow light and dark mode, and doc comments on every public MFA symbol.
- Guardian Push implement via MFA [\#76](https://github.com/auth0/ui-components-ios/pull/76) ([Sudhanshu96](https://github.com/Sudhanshu96))
- MFA Core functionality implemented making it a stand alone feature [\#79](https://github.com/auth0/ui-components-ios/pull/79) ([Sudhanshu96](https://github.com/Sudhanshu96))

**Changed**

- Embedded Login keeps the email when the user comes back to email entry: Back from code entry or MFA, **Try again**, **Start over** or **Sign in again**.
- Embedded Login now advertises only the steps it can render (Email OTP and Guardian push) in its `authorize` capabilities.
- Requires Auth0.swift `4.0.0-beta.1` or later 4.x, the first release with the push APIs.
- Error screens never show the SDK's internal codes (e.g. `too_many_attempts`); rate limits, IP blocks and consent errors get their own copy.
- The **Resend** countdowns keep time while the screen redraws, and announce the time left to VoiceOver.
- The push screen no longer names the Guardian app (customers may ship their own authenticator), says **Resend notification** instead of **Resend Code**, and has its own sentence for a device with no name.

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
