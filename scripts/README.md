# Auth0 Tenant Bootstrap Script (iOS)

An interactive CLI that configures your Auth0 tenant with everything the
**AppUIComponents** sample app needs, then wires the app up locally by writing
`Auth0.plist` and registering the OAuth callback URL scheme. The script
discovers existing resources, builds a change plan, and only creates what's
missing — it never modifies configuration that is already correct.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [What It Configures](#what-it-configures)
- [Auth0 CLI Scopes](#auth0-cli-scopes)
- [Manual Configuration](#manual-configuration)

## Prerequisites

1. **Node.js 20 or later** — [nodejs.org](https://nodejs.org/)
2. **Auth0 CLI** — [github.com/auth0/auth0-cli](https://github.com/auth0/auth0-cli)
3. **An Auth0 tenant** — sign up at [auth0.com/signup](https://auth0.com/signup)
   if you don't have one. You can use an existing tenant; the script only adds
   what's missing.

> ⚠️ **Note:** You do not need to log in to the Auth0 CLI beforehand. The script
> checks your CLI session and, if it is missing or expired, offers to log you in
> (requesting the [required scopes](#auth0-cli-scopes)) and switch to the
> requested tenant automatically.

## Usage

Run from the `scripts/` directory:

```bash
cd scripts
npm install
npm run auth0:bootstrap <your-tenant-domain>
```

The tenant domain argument is required (e.g. `my-tenant.us.auth0.com`) as a
safety measure to prevent accidentally configuring the wrong tenant.

The script guides you through:

1. **Pre-flight checks** — Node version, Auth0 CLI install, CLI session, and
   Carthage dependencies. If your session is expired it offers to log you in;
   if the Carthage frameworks are missing it runs
   `carthage bootstrap --use-xcframeworks` so the Xcode project can build.
2. **Tenant validation** — confirms the provided domain matches your active CLI
   tenant. On a mismatch it offers to `auth0 tenants use <tenant>` (switch) or
   log in to it, then continues.
3. **Resource discovery** — scans the tenant and warns (softly) if the My
   Account API is missing MFA scopes.
4. **Change plan review** — displays what will be created, updated, or skipped.
5. **Confirmation** — prompts for approval before applying any changes.
6. **Apply changes** — creates and configures the required Auth0 resources.
7. **Local wiring** — writes `AppUIComponents/Auth0.plist` and registers the
   app's callback URL scheme in `AppUIComponents/Info.plist` (idempotent).

## What It Configures

| Resource                | Details                                                                                         |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| **Native Application**  | `iOS UI Components Demo` (`app_type: native`). Callback + logout URLs use the app's bundle identifier (`https://{domain}/ios/{bundleId}/callback` and `{bundleId}://{domain}/ios/{bundleId}/callback`), plus refresh-token rotation and a My Account API refresh-token policy |
| **My Account API**      | Resource server at `https://{domain}/me/` (MFA / authentication-methods)                        |
| **Client Grant**        | Native app authorized for the available My Account API scopes                                   |
| **Database Connection** | `Username-Password-Authentication` enabled for the app, with the **passkey** authentication method turned on (progressive enrollment) so the Passkey option appears in Universal Login |
| **MFA Factors**         | WebAuthn factors enabled — `webauthn-platform` (Face ID / Touch ID) and `webauthn-roaming` (security keys) — so the MFA components have factors to enroll |
| **Tenant Settings**     | Identifier-first prompt (required for the Passkey prompt) and MFA customization in the post-login action |

Locally, it then writes:

- `AppUIComponents/Auth0.plist` — `Domain` and `ClientId` read by the SDK at
  launch (`Auth0UniversalComponentsSDKInitializer`).
- `AppUIComponents/Info.plist` — a `CFBundleURLTypes` entry registering the
  app's bundle identifier as a URL scheme so the login/logout callback returns
  to the app.

## Auth0 CLI Scopes

If the script triggers a login, it requests the required scopes automatically.
To authenticate manually beforehand, run `npm run auth0:bootstrap --help`, which
prints the exact, always-up-to-date `auth0 login --scopes "…"` command (the list
is generated from the script's scope definitions, so it can never drift from
what the script actually requests).

## Manual Configuration

If you prefer to configure the tenant by hand, follow **Option 2: Manual Setup**
in the [root README](../README.md#option-2-manual-setup), which covers creating
the native application, allowed callback URLs, `AppUIComponents/Auth0.plist`,
and the `Info.plist` URL scheme.
