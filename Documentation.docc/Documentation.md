# ``Auth0UniversalComponents``

SDK for Apple platforms.

## Overview

- ``Auth0UniversalComponents/TokenProvider``: Token provider protocol for implementing methods for storing and retrieving credentials required for SDK.

- ``Auth0UniversalComponents/Auth0UniversalComponentsSDKInitializer``: Actor to store dependencies required for SDK.

- ``Auth0UniversalComponents/MyAccountAuthMethodsView``: A SwiftUI view to view the available MFA auth methods for enrollment. Tapping on each MFA factor will either start enrollment flow or view the enolled auth methods

## Loading States

While fetching data, the card screens render animated **skeleton shimmer** placeholders that mirror the loaded layout. The shimmer adapts to light/dark mode, follows the active ``Auth0Theme``, and falls back to a static placeholder when **Reduce Motion** is enabled. No configuration is required.

## Customisation

- <doc:ThemeSystem>: Inject a custom ``Auth0Theme`` to match the SDK's colours, typography, spacing, corner radii, and component sizes to your brand — with zero configuration required for the default Auth0 look.
