
### Auth0 Swift UI Components + Sample App

UI building blocks for MFA enrollment and verification on Apple platforms built on top of Auth0.swift SDK, plus a runnable sample app that shows how to integrate them in a real app.

This repo contains:
- `Auth0UIComponents`: a reusable Swift library (Swift + SwiftUI) that implements MFA flows (TOTP, Push, SMS, Email, Recovery Codes) on top of the Auth0 Swift SDK and My Account APIs.
- `app`: a minimal sample application that initializes Auth0, logs users in via Universal Login, and embeds the MFA UI components.

---

### Requirements

- iOS 16.0+ / macOS 11.0+ / tvOS 14.0+ / watchOS 7.0+
- Xcode 16.x
- Swift 6.0+

---

### Installation

#### Using the Swift Package Manager

Open the following menu item in Xcode:

**File > Add Package Dependencies...**

In the **Search or Enter Package URL** search box enter this URL: 

```text
https://github.com/auth0/ui-components-ios

```

Then, select the dependency rule and press **Add Package**.

#### Using Cocoapods

Add the following line to your `Podfile`:

```ruby
pod 'Auth0UIComponents'
```

Then, run `pod install`.

#### Using Carthage

Add the following line to your `Cartfile`:

```text
github "auth0/ui-components-ios"
```

Then, run `carthage bootstrap --use-xcframeworks`.

### Project structure

```
Auth0UIComponents/
├─ AppUIComponents/                # Sample app 
└─ Auth0UIComponents/      # Reusable MFA UI library
```

---

#### Configure Auth0 for the sample app

1) Create a Native application in your Auth0 tenant and note the Client ID and Domain.

2) Configure Allowed Callback URLs for iOS. The sample uses an callback of the form:

	 ##### iOS

```text
https://YOUR_AUTH0_DOMAIN/ios/YOUR_BUNDLE_IDENTIFIER/callback,
YOUR_BUNDLE_IDENTIFIER://YOUR_AUTH0_DOMAIN/ios/YOUR_BUNDLE_IDENTIFIER/callback
```

##### macOS

```text
https://YOUR_AUTH0_DOMAIN/macos/YOUR_BUNDLE_IDENTIFIER/callback,
YOUR_BUNDLE_IDENTIFIER://YOUR_AUTH0_DOMAIN/macos/YOUR_BUNDLE_IDENTIFIER/callback
```

	 If you change the bundle identifier or scheme/domain values, update the callback accordingly.

3) Create Auth0.plist in the App target and Set your Auth0 values in the Auth0.plist file:
Create a `plist` file named `Auth0.plist` in your app bundle with the following content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ClientId</key>
    <string>YOUR_AUTH0_CLIENT_ID</string>
    <key>Domain</key>
    <string>YOUR_AUTH0_DOMAIN</string>
</dict>
</plist>
```

4)  Audience configuration

	 The sample sets the audience to your tenant’s Management API v2 endpoint:
	 `https://{domain}/api/v2/`

	 Ensure your application is configured to allow this audience if you plan to request tokens for APIs that back My Account operations.

---

#### Run the sample app

From Xcode:
- Open the terminal with project folder as current directory
- Run `Carthage bootstrap --use-xcframeworks` command
- Open the app in xcode by clicking twice on `Auth0UIComponents.xcodeproj`
- Select `AppUIComponents` Target and click Run on a device/simulator (iOS 16+).

---

#### What you’ll see in the sample

1) Launch the app → you’ll land on a simple Login screen.
2) Tap Login → Universal Login opens in the browser; complete authentication.
3) After success, you’re navigated to Settings, which embeds the MFA UI Components. From here you can:
	 - View available MFA methods
	 - Enroll TOTP or Push via QR
	 - Enroll SMS or Email and verify via OTP
	 - Generate and copy Recovery Codes

---

#### Using the SDK in your app

Every time you want to display the initial view for displaying auth methods. Provide:
- a `TokenProvider` (the sample uses `CredentialsManager()`), and
- a `Bundle` instance for accessing assets like images and colors

Minimal setup (Swift):

```swift
Auth0UIComponents.myAcountAuthView(bundle: yourApporFrameworkBundle,
                                   tokenProvider: yourTokenProvider)
```

Navigation inside MFA is handled internally by the SDK.

---

### Troubleshooting

- Login completes but API calls fail (401/403):
	- Confirm the audience/scopes and that your application is authorized to call the APIs backing My Account flows.

- SMS/Email OTP not received:
	- Ensure those factors are enabled and configured in your Auth0 tenant and the test device/number/email is reachable.

---
