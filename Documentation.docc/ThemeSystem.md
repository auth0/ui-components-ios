# Theming Auth0 UI Components

Customise colours, typography, spacing, corner radii, and component sizes to match your brand — with zero boilerplate for the default Auth0 look.

## Overview

Auth0 UI Components ships with a fully injectable theme system. Every visual property — colours, fonts, spacing, corner radii, and component dimensions — is expressed as a **design token**: a named constant that carries a design decision, not a raw value.

> **What is a design token?**
> A design token is a single source of truth for a visual property. Instead of writing `Color(hex: "#1F1F1F")` in dozens of places, you write `theme.colors.primary` once. If the brand colour changes, you update one token and every component updates automatically — no search-and-replace required.

The system is built on SwiftUI's `@Environment`, which means themes are injected from the outside (at the app/screen level) and consumed automatically by every SDK view beneath.

---

### Three-Layer Architecture

The theme is organised in three layers that separate raw values from their meaning:

```
┌─────────────────────────────────────────────────┐
│  Layer 3 — Injection                            │
│  Auth0Theme  ·  .auth0Theme(_:)  ·  @Environment│
└──────────────────────┬──────────────────────────┘
                       │  injects token set
┌──────────────────────▼──────────────────────────┐
│  Layer 2 — Semantic tokens  (public API)        │
│  Auth0ColorTokens    ·  DefaultAuth0ColorTokens │
│  Auth0TypographyTokens ·  …SizeTokens  …etc.   │
└──────────────────────┬──────────────────────────┘
                       │  maps role → palette step
┌──────────────────────▼──────────────────────────┐
│  Layer 1 — Palette  (raw values)                │
│  Colors.xcassets                                │
│    Neutral/1 … Neutral/12  (greyscale scale)    │
│    Red/1     … Red/12      (red / error scale)  │
│    Green/1   … Green/12    (green / success)    │
└─────────────────────────────────────────────────┘
```

**Layer 1 (Palette)** stores the raw, brand-agnostic colour values in `Colors.xcassets`. Every palette entry is an *adaptive* colorset — a single asset that contains both a light-mode and a dark-mode swatch. Separating the palette from semantic names means the entire colour system is interchangeable: swap the palette, keep the semantics, or keep the palette and redefine the semantics.

**Layer 2 (Semantic tokens)** is the public API. The `Auth0ColorTokens` protocol defines *roles* (`primary`, `onError`, `textSecondary`, …) that the SDK's views consume. `DefaultAuth0ColorTokens` wires each role to a palette step — for example, `primary → Neutral/12` and `onError → Red/12`. This is the *only* place the palette-to-semantic mapping exists.

**Layer 3 (Injection)** wraps the active token set in a plain `Auth0Theme` struct and pushes it through the SwiftUI Environment with a single `.auth0Theme(_:)` modifier.

---

### For Designers — How Tokens Map to the UI

The five token categories map directly to the visual properties a designer controls in a design tool:

| Token category | What it controls | Analogy in design tool |
|---|---|---|
| **Colors** | Every colour used in the UI — backgrounds, text, borders, icons | Colour styles / swatches library |
| **Typography** | Font family, weight, size, line height, and letter-spacing for each text role | Text styles library |
| **Spacing** | Padding and gap values between elements | Spacing/grid variables |
| **Radius** | Corner rounding of buttons, cards, and input fields | Corner radius presets |
| **Sizes** | Fixed dimensions — button heights, icon sizes, input cell dimensions | Component size specs |

> **For designers:** When you hand off a design that uses a different colour for the primary button, you provide the hex value for `primary` (and `onPrimary` for the button label). The engineer overrides that single token; nothing else in the layout needs to change.

---

### For Product — What You Get Out of the Box

Without any configuration the SDK renders with the default Auth0 visual identity — correct colours, typography, spacing, and corner radii. You do not need to pass any theme to any view.

The default theme:
- Uses the **Inter** typeface (bundled; falls back to SF Pro if unavailable)
- Follows Auth0's neutral, accessible greyscale palette with red/green feedback colours
- Supports **light and dark mode** automatically — every colour token has a light and a dark swatch
- Meets minimum contrast ratios for body text on all default surfaces

If a partner or enterprise customer needs brand customisation, any token (or group of tokens) can be overridden by an engineer in one place — no changes are required inside the SDK.

---

## Zero Configuration

Auth0 UI Components work without any theme setup. The default Auth0 palette is used automatically:

```swift
struct ContentView: View {
    var body: some View {
        MyAccountAuthMethodsView()
    }
}
```

---

## Partial Token Override

Use ``DefaultAuth0ColorTokens``'s init parameters to change only the tokens you need. All others keep the built-in Auth0 values:

```swift
import Auth0UIComponents

struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MyAccountAuthMethodsView()
                .auth0Theme(
                    Auth0Theme(
                        colors: DefaultAuth0ColorTokens(
                            primary: Color("BrandBlue"),
                            onPrimary: .white
                        )
                    )
                )
        }
    }
}
```

The same pattern applies to all other token categories:

```swift
Auth0Theme(
    typography: DefaultAuth0TypographyTokens(
        body: Auth0TextStyle(font: .custom("Lato-Regular", size: 17), tracking: 0, lineSpacing: 7),
        label: Auth0TextStyle(font: .custom("Lato-Medium", size: 16), tracking: 0.1, lineSpacing: 5)
    ),
    radius: DefaultAuth0RadiusTokens(button: 24)  // pill-shaped buttons
)
```

---

## Full Category Override

For complete brand alignment, implement the `Auth0ColorTokens` protocol and supply your own palette → semantic mapping:

```swift
// Your brand's own palette, defined in your app's asset catalog
struct BrandColors: Auth0ColorTokens {
    var primary:          Color { Color("Brand/Blue/900") }
    var onPrimary:        Color { Color("Brand/Blue/50") }
    var background:       Color { Color("Brand/Neutral/50") }
    var surface:          Color { Color("Brand/Neutral/100") }
    var onSurface:        Color { Color("Brand/Neutral/600") }
    var border:           Color { Color("Brand/Neutral/300") }
    var error:            Color { Color("Brand/Red/100") }
    var errorContainer:   Color { Color("Brand/Red/50") }
    var onError:          Color { Color("Brand/Red/800") }
    var success:          Color { Color("Brand/Green/100") }
    var successContainer: Color { Color("Brand/Green/50") }
    var onSuccess:        Color { Color("Brand/Green/800") }
    var textPrimary:      Color { Color("Brand/Neutral/900") }
    var textSecondary:    Color { Color("Brand/Neutral/600") }
    var foreground:       Color { Color("Brand/Neutral/900") }
    var cardForeground:   Color { .black }
    var mutedForeground:  Color { Color("Brand/Neutral/500") }
}

MyAccountAuthMethodsView()
    .auth0Theme(Auth0Theme(colors: BrandColors()))
```

---

## In-Place Mutation

Because ``Auth0Theme`` is a struct with `var` properties, you can start from the default and mutate individual categories before injecting:

```swift
var theme = Auth0Theme()
theme.colors     = BrandColors()
theme.typography = DefaultAuth0TypographyTokens(
    displayMedium: Auth0TextStyle(font: .custom("Poppins-SemiBold", size: 28), tracking: -0.1, lineSpacing: 6)
)

MyAccountAuthMethodsView().auth0Theme(theme)
```

---

## Using the Theme in Custom Views

If you build views that extend Auth0 UI Components — for example, a custom enrollment screen — read the active theme from the environment:

```swift
struct MyCustomStep: View {
    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.base) {
            Text("Almost there!")
                .auth0TextStyle(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)

            Button("Continue") { /* … */ }
                .frame(height: theme.sizes.buttonHeight)
                .background(theme.colors.primary)
                .cornerRadius(theme.radius.button)
        }
        .padding(theme.spacing.base)
    }
}
```

---

## Token Reference

### Colors — ``Auth0ColorTokens``

The colour system is **two-layer**: a raw palette (stored in `Colors.xcassets`) and semantic tokens that map onto it. Every palette entry is an adaptive colorset — a single asset with both light and dark swatches.

> **For designers:** The palette is the set of raw colour values (e.g. `Neutral/12` = near-black in light mode). Semantic tokens assign a *role* to each palette step (e.g. `primary` uses `Neutral/12`). Always refer to the semantic token name in design files, not the hex value — this ensures light/dark mode works without any extra effort.

#### Palette reference

| Asset | Light (hex) | Dark (hex) |
|---|---|---|
| `Neutral/1` | `#FCFCFC` | `#111111` |
| `Neutral/2` | `#F8F8F8` | `#191919` |
| `Neutral/3` | `#F5F5F5` | `#222222` |
| `Neutral/4` | `#EBEBEB` | `#2C2C2C` |
| `Neutral/5` | `#E0E0E0` | `#333333` |
| `Neutral/6` | `#D9D9D9` | `#3A3A3A` |
| `Neutral/7` | `#C2C2C2` | `#4D4D4D` |
| `Neutral/8` | `#ABABAB` | `#666666` |
| `Neutral/9` | `#929292` | `#808080` |
| `Neutral/10` | `#7B7B7B` | `#9A9A9A` |
| `Neutral/11` | `#636363` | `#B4B4B4` |
| `Neutral/12` | `#1F1F1F` | `#EEEEEE` |
| `Red/1` | `#FFFCFC` | `#180E0D` |
| `Red/3` | `#FEE8E6` | `#400D07` |
| `Red/12` | `#863C2D` | `#FFCFC5` |
| `Green/1` | `#FAFEFB` | `#0C130E` |
| `Green/3` | `#E6F7EA` | `#152D1C` |
| `Green/12` | `#1B3D26` | `#B1F2C2` |
| `Muted` | `#F4F4F5` | `#18181B` |

#### Default semantic → palette mapping

| Semantic token | Default palette step | Usage |
|---|---|---|
| `primary` | `Neutral/12` | CTA button background, primary borders |
| `onPrimary` | `Neutral/3` | Text and icons on a `primary` surface |
| `background` | `Neutral/1` | Main app background |
| `surface` | `Neutral/1` | Card and container backgrounds |
| `onSurface` | `Neutral/11` | Secondary text and icons on surfaces |
| `border` | `Neutral/6` | Input field and card borders |
| `error` | `Red/3` | Error state container background |
| `errorContainer` | `Red/1` | Subtle error banner background |
| `onError` | `Red/12` | Text and icons on error surfaces, validation messages |
| `success` | `Green/3` | Success state container background |
| `successContainer` | `Green/1` | Subtle success banner background |
| `onSuccess` | `Green/12` | Text and icons on success surfaces |
| `textPrimary` | `Neutral/12` | Headings and primary body text |
| `textSecondary` | `Neutral/11` | Descriptions, captions, secondary copy |
| `foreground` | `Neutral/12` | General foreground content (text, icons) |
| `cardForeground` | `Color.black` | Text and icons on card surfaces (non-adaptive) |
| `mutedForeground` | `Neutral/10` | Placeholder text, de-emphasised content on muted backgrounds |

---

### Typography — ``Auth0TypographyTokens``

Every token is an ``Auth0TextStyle`` value bundling `font`, `tracking`, and `lineSpacing` together. Apply one with the `.auth0TextStyle(_:)` view modifier to ensure all three properties are set atomically.

> **For designers:** Each row in the table below corresponds to a text style in the design file. The `tracking` column maps to *letter-spacing* and `lineSpacing` maps to *line-height*. When handing off a custom typeface, provide the `font`, `tracking`, and `lineSpacing` for each role that changes.

| Token | Typeface | Size | Weight | Line height | Tracking | Usage |
|---|---|---|---|---|---|---|
| `displayLarge` | Inter | 34 pt | SemiBold | 41 pt | −0.20 pt | Hero / feature headings, passkey enrollment |
| `displayMedium` | Inter | 28 pt | SemiBold | 34 pt | −0.10 pt | Major screen titles, error headings |
| `display` | Inter | 22 pt | SemiBold | 28 pt | −0.05 pt | Section-level headings |
| `titleLarge` | Inter | 20 pt | SemiBold | 25 pt | 0 pt | Screen titles, subheading cards |
| `title` | Inter | 17 pt | SemiBold | 24 pt | 0 pt | In-content titles |
| `body` | Inter | 17 pt | Regular | 24 pt | 0 pt | Descriptions, body copy |
| `bodySmall` | Inter | 15 pt | Regular | 20 pt | +0.10 pt | Secondary body copy, footnotes |
| `label` | Inter | 16 pt | Medium | 21 pt | +0.10 pt | Button labels, form field labels |
| `helper` | Inter | 13 pt | Regular | 18 pt | +0.20 pt | Captions, helper text, secondary labels |
| `overline` | Inter | 11 pt | Regular | 16 pt | +0.77 pt | Overline / category labels |

> **Font fallback:** If Inter is not bundled in the host app, SwiftUI falls back to SF Pro automatically — no crash or broken layout.

```swift
// Apply a single token:
Text("Continue")
    .auth0TextStyle(theme.typography.label)
    .foregroundStyle(theme.colors.onPrimary)
```

---

### Spacing — ``Auth0SpacingTokens``

The spacing scale is based on a **4 pt grid**. Every token is a multiple of 4, which ensures components always snap to a consistent visual rhythm.

> **For designers:** These values correspond to the spacing variables in your design tool. Use the token name (e.g. `base`) rather than the pixel value when annotating specs — this allows engineering to automatically adapt spacing if the scale is ever adjusted.

| Token | Default | Description |
|---|---|---|
| `xs` | 4 pt | Minimal gap between tightly coupled elements |
| `sm` | 8 pt | Small gap between grouped elements |
| `md` | 12 pt | Medium internal padding |
| `base` | 16 pt | Standard component and container padding |
| `lg` | 20 pt | Larger padding for major sections |
| `xl` | 24 pt | Extra-large padding |
| `2xl` | 32 pt | Double-extra-large padding |
| `3xl` | 40 pt | Triple-extra-large padding |
| `4xl` | 48 pt | Quadruple-extra-large padding |
| `5xl` | 56 pt | Quintuple-extra-large padding |

---

### Radius — ``Auth0RadiusTokens``

Corner radii create visual hierarchy: tighter curves on small cells, softer curves on buttons, and fully rounded ends on pill-shaped controls.

> **For designers:** Assign one of these named tokens to each component's corner radius in the design file. Avoid specifying raw pixel values for corners — use the token name so any brand rounding adjustment cascades automatically.

| Token | Default | Usage |
|---|---|---|
| `small` | 8 pt | Single character-input cells (OTP, PIN digits) |
| `medium` | 12 pt | Banner and feedback cards |
| `inputField` | 14 pt | Text inputs, code display containers |
| `button` | 16 pt | CTA buttons, auth-method cards |
| `pill` | 24 pt | Pill-shaped outline buttons |

---

### Sizes — ``Auth0SizeTokens``

Fixed component dimensions that define the height, width, and icon scale of SDK elements. These are the values designers annotate on component specs.

> **For designers:** The `size4xlDimen` and `size5xlDimen` tokens control the width and height of each individual digit cell in a code-entry field (OTP, PIN, etc.). The `containerSizeLargeDimen` token controls the height of any read-only code display box (recovery codes, secret keys). Adjusting these tokens resizes the entire component consistently across all screens.

| Token | Default | Usage |
|---|---|---|
| `buttonHeight` | 48 pt | All primary and secondary action buttons |
| `inputHeight` | 60 pt | Text and phone-number input fields |
| `size4xlDimen` | 48 pt | Width of a single character-input cell (OTP digit, PIN digit, etc.) |
| `size5xlDimen` | 56 pt | Height of a single character-input cell (OTP digit, PIN digit, etc.) |
| `containerSizeLargeDimen` | 52 pt | Height of a read-only code display container (recovery code, TOTP secret, etc.) |
| `iconSmall` | 16 pt | Small icons — chevrons, info indicators, checkmarks |
| `iconMedium` | 24 pt | Standard icons — authentication-method images |
| `iconLarge` | 28 pt | Large icons — three-dots menu button |

---

## Topics

### Theme Container
- ``Auth0Theme``

### Color Tokens
- ``Auth0ColorTokens``
- ``DefaultAuth0ColorTokens``

### Typography Tokens
- ``Auth0TypographyTokens``
- ``DefaultAuth0TypographyTokens``

### Spacing Tokens
- ``Auth0SpacingTokens``
- ``DefaultAuth0SpacingTokens``

### Radius Tokens
- ``Auth0RadiusTokens``
- ``DefaultAuth0RadiusTokens``

### Size Tokens
- ``Auth0SizeTokens``
- ``DefaultAuth0SizeTokens``
