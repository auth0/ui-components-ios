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
                       │  maps role → palette entry
┌──────────────────────▼──────────────────────────┐
│  Layer 1 — Palette  (raw values)                │
│  Colors.xcassets  (Mobile Design System namespaces) │
│    Background/Primary … Background/Accent       │
│    Border/Bold    … Border/Shadow               │
│    Text/Bold      … Text/OnError                │
└─────────────────────────────────────────────────┘
```

**Layer 1 (Palette)** stores the raw colour values in `Colors.xcassets`, organised into three Mobile Design System namespaces: `Background/`, `Border/`, and `Text/`. Every palette entry is an *adaptive* colorset — a single asset that contains both a light-mode and a dark-mode swatch. Separating the palette from semantic names means the entire colour system is interchangeable: swap the palette, keep the semantics, or keep the palette and redefine the semantics.

**Layer 2 (Semantic tokens)** is the public API. Colours are split across three focused protocols — ``Auth0BackgroundColorTokens``, ``Auth0TextColorTokens``, and ``Auth0BorderColorTokens`` — each mapping roles onto palette entries. `Auth0ColorTokens` is a thin container that aggregates all three under `background`, `text`, and `border` properties. SDK views consume tokens via `theme.colors.background.primary`, `theme.colors.text.bold`, etc.

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

> **For designers:** When you hand off a design that uses a different colour for the primary button, you provide the hex value for `background.primary` (and `text.onPrimary` for the button label). The engineer overrides those tokens; nothing else in the layout needs to change.

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

Pass a custom `Default*` sub-struct for the colour category you want to change. All other tokens in that category keep the built-in Auth0 values:

```swift
import Auth0UniversalComponents

struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MyAccountAuthMethodsView()
                .auth0Theme(
                    Auth0Theme(
                        colors: DefaultAuth0ColorTokens(
                            background: DefaultAuth0BackgroundColorTokens(primary: Color("BrandBlue")),
                            text: DefaultAuth0TextColorTokens(onPrimary: .white)
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

For complete brand alignment, implement the three colour category protocols and wire them together into an `Auth0ColorTokens` container:

```swift
// Your brand's background colours — sourced from your app's asset catalog
struct BrandBackground: Auth0BackgroundColorTokens {
    var primary:       Color { Color("Background/Primary",       bundle: .main) }
    var primarySubtle: Color { Color("Background/Primary",       bundle: .main).opacity(0.35) }
    var inverse:       Color { Color("Background/Inverse",       bundle: .main) }
    var accent:        Color { Color("Background/Accent",        bundle: .main) }
    var layerTop:      Color { Color("Background/LayerTop",      bundle: .main) }
    var layerMedium:   Color { Color("Background/LayerMedium",   bundle: .main) }
    var layerBase:     Color { Color("Background/LayerBase",     bundle: .main) }
    var error:         Color { Color("Background/Error",         bundle: .main) }
    var errorSubtle:   Color { Color("Background/ErrorSubtle",   bundle: .main) }
    var success:       Color { Color("Background/Success",       bundle: .main) }
    var successSubtle: Color { Color("Background/SuccessSubtle", bundle: .main) }
}

// Your brand's text colours — sourced from your app's asset catalog
struct BrandText: Auth0TextColorTokens {
    var bold:      Color { Color("Text/Bold",      bundle: .main) }
    var regular:   Color { Color("Text/Default",   bundle: .main) }
    var disabled:  Color { Color("Text/Disabled",  bundle: .main) }
    var onPrimary: Color { Color("Text/OnPrimary", bundle: .main) }
    var onSuccess: Color { Color("Text/OnSuccess", bundle: .main) }
    var onError:   Color { Color("Text/OnError",   bundle: .main) }
}

// Your brand's border colours — sourced from your app's asset catalog
struct BrandBorder: Auth0BorderColorTokens {
    var bold:    Color { Color("Border/Bold",    bundle: .main) }
    var regular: Color { Color("Border/Default", bundle: .main) }
    var subtle:  Color { Color("Border/Subtle",  bundle: .main) }
    var shadow:  Color { Color("Border/Shadow",  bundle: .main) }
}

// Container that wires the three categories together
struct BrandColors: Auth0ColorTokens {
    var background: any Auth0BackgroundColorTokens { BrandBackground() }
    var text:       any Auth0TextColorTokens       { BrandText() }
    var border:     any Auth0BorderColorTokens     { BrandBorder() }
}

MyAccountAuthMethodsView()
    .auth0Theme(Auth0Theme(colors: BrandColors()))
```

---

## In-Place Mutation

Because ``Auth0Theme`` is a struct with `var` properties, you can start from the default and mutate individual categories before injecting:

```swift
var theme = Auth0Theme()
theme.colors     = BrandColors()     // BrandColors implements Auth0ColorTokens
theme.typography = DefaultAuth0TypographyTokens(
    displayMedium: Auth0TextStyle(font: .custom("Poppins-SemiBold", size: 28), tracking: -0.1, lineSpacing: 6)
)

MyAccountAuthMethodsView().auth0Theme(theme)
```

You can also mutate a single colour category inline without replacing the whole colour set:

```swift
var theme = Auth0Theme()
theme.colors = DefaultAuth0ColorTokens(
    background: DefaultAuth0BackgroundColorTokens(primary: Brand.blue),
    text: DefaultAuth0TextColorTokens(onPrimary: .white)
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
        VStack(spacing: theme.spacing.md) {
            Text("Almost there!")
                .auth0TextStyle(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.text.bold)

            Button("Continue") { /* … */ }
                .frame(height: theme.sizes.buttonHeight)
                .background(theme.colors.background.primary)
                .cornerRadius(theme.radius.button)
        }
        .padding(theme.spacing.md)
    }
}
```

---

## Token Reference

### Colors — ``Auth0ColorTokens``

The colour system is **two-layer**: a raw palette (stored in `Colors.xcassets`) and semantic tokens that map onto it. Every palette entry is an adaptive colorset — a single asset with both light and dark swatches.

> **For designers:** The palette is organised into three Mobile Design System namespaces — `Background`, `Border`, and `Text`. Every colorset is *adaptive*: a single asset that contains both a light-mode and a dark-mode swatch. Semantic tokens map roles (e.g. `background.primary`) onto palette entries. Always refer to the semantic token name in design files, not the hex value — this ensures light/dark mode works without any extra effort.

#### Palette reference

**Background — Primary**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Background/Primary` | `#09090B` | `#FAFAFA` | Default background for CTA buttons and primary surfaces |
| `Background/PrimarySubtle` | `#09090B · 35%` | `#FAFAFA · 50%` | Low-emphasis primary background |
| `Background/Inverse` | `#18181B` | `#FAFAFA` | Contrast-flipped background |
| `Background/Accent` | `#09090B` | `#A7F3D0` | Branded / featured UI highlight |

**Background — Layers**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Background/LayerTop` | `#FFFFFF` | `#3F3F46` | Top-most layer — overlays, modals, popovers |
| `Background/LayerMedium` | `#FCFCFC` | `#27272A` | Mid-level layer — cards, raised containers |
| `Background/LayerBase` | `#F4F4F5` | `#09090B` | Foundational layer — main app background |

**Background — Feedback**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Background/Error` | `#FEE2E2` | `#FDA4AF` | Error state container background |
| `Background/ErrorSubtle` | `#FEF2F2` | `#BE123C` | Muted error banner background |
| `Background/Success` | `#E6F7EA` | `#A7F3D0` | Success state container background |
| `Background/SuccessSubtle` | `#FAFEFB` | `#059669` | Muted success banner background |

**Border — Emphasis**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Border/Bold` | `#A1A1AA` | `#71717A` | High-contrast border, selected elements |
| `Border/Default` | `#D9D9D9` | `#3F3F46` | Standard border for most containers |
| `Border/Subtle` | `#E4E4E7` | transparent | Delicate dividers |

**Border — Elevation**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Border/Shadow` | `#CECECE · 50%` | `#3F3F46` | Depth / elevation shadow border |

**Text — Content**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Text/Bold` | `#1F1F1F` | `#FAFAFA` | High-emphasis headings and body text |
| `Text/Default` | `#636363` | `#A1A1AA` | Lower-emphasis body, captions |
| `Text/Disabled` | `#8E8E8E` | `#52525B` | Disabled and placeholder text |

**Text — On Color**

| Asset | Light (hex) | Dark (hex) | Description |
|---|---|---|---|
| `Text/OnPrimary` | `#F0F0F0` | `#18181B` | Text and icons on a primary background |
| `Text/OnSuccess` | `#6EE7B7` | `#A7F3D0` | Text and icons on a success background |
| `Text/OnError` | `#991B1B` | `#FFCFC5` | Text and icons on an error background |

#### Default semantic → palette mapping

**Background — Primary**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `backgroundPrimary` | `Background/Primary` | CTA button background, primary borders |
| `backgroundPrimarySubtle` | `Background/PrimarySubtle` | Low-emphasis primary background |
| `backgroundInverse` | `Background/Inverse` | Contrast-flipped background |
| `backgroundAccent` | `Background/Accent` | Branded / featured UI highlight |

**Background — Layers**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `backgroundLayerTop` | `Background/LayerTop` | Overlay and modal backgrounds |
| `backgroundLayerMedium` | `Background/LayerMedium` | Card and container backgrounds |
| `backgroundLayerBase` | `Background/LayerBase` | Main app background |

**Background — Feedback**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `backgroundError` | `Background/Error` | Error state container background |
| `backgroundErrorSubtle` | `Background/ErrorSubtle` | Subtle error banner background |
| `backgroundSuccess` | `Background/Success` | Success state container background |
| `backgroundSuccessSubtle` | `Background/SuccessSubtle` | Subtle success banner background |

**Border — Emphasis**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `borderBold` | `Border/Bold` | High-contrast / selected borders |
| `borderDefault` | `Border/Default` | Input field and card borders |
| `borderSubtle` | `Border/Subtle` | Delicate dividers |

**Border — Elevation**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `borderShadow` | `Border/Shadow` | Depth and elevation shadow |

**Text — Content**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `textBold` | `Text/Bold` | Headings, primary body text, and icons |
| `textDefault` | `Text/Default` | Secondary copy, descriptions, and captions |
| `textDisabled` | `Text/Disabled` | Disabled and placeholder text |

**Text — On Color**

| Semantic token | Default palette entry | Usage |
|---|---|---|
| `textOnPrimary` | `Text/OnPrimary` | Text and icons on a `backgroundPrimary` surface |
| `textOnSuccess` | `Text/OnSuccess` | Text and icons on a `backgroundSuccess` surface |
| `textOnError` | `Text/OnError` | Text and icons on a `backgroundError` surface, validation messages |

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
    .foregroundStyle(theme.colors.textOnPrimary)
```

---

### Spacing — ``Auth0SpacingTokens``

The spacing scale is based on a **4 pt grid**. Every token is a multiple of 4, which ensures components always snap to a consistent visual rhythm.

> **For designers:** These values correspond to the spacing variables in your design tool. Use the token name (e.g. `base`) rather than the pixel value when annotating specs — this allows engineering to automatically adapt spacing if the scale is ever adjusted.

| Token | Default | Description |
|---|---|---|
| `xxs` | 4 pt | Minimal gap between tightly coupled elements |
| `xs` | 8 pt | Small gap between grouped elements |
| `sm` | 12 pt | Medium internal padding |
| `md` | 16 pt | Standard component and container padding |
| `lg` | 24 pt | Larger padding for major sections |
| `xl` | 32 pt | Extra-large padding |
| `xxl` | 48 pt | Double-extra-large padding |
| `xxxl` | 56 pt | Triple-extra-large padding |

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

### Color Tokens — Container
- ``Auth0ColorTokens``
- ``DefaultAuth0ColorTokens``

### Color Tokens — Background
- ``Auth0BackgroundColorTokens``
- ``DefaultAuth0BackgroundColorTokens``

### Color Tokens — Text
- ``Auth0TextColorTokens``
- ``DefaultAuth0TextColorTokens``

### Color Tokens — Border
- ``Auth0BorderColorTokens``
- ``DefaultAuth0BorderColorTokens``

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
