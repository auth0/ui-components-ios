# ``Auth0UIComponents``

SDK for Apple platforms.

## Overview

- ``Auth0UIComponents/TokenProvider``: Token provider protocol for implementing methods for storing and retrieving credentials required for SDK.

- ``Auth0UIComponents/Auth0UIComponentsSDKInitializer``: Actor to store dependencies required for SDK.

- ``Auth0UIComponents/MyAccountAuthMethodsView``: A SwiftUI view to view the available MFA auth methods for enrollment. Tapping on each MFA factor will either start enrollment flow or view the enolled auth methods

## Customisation

- <doc:ThemeSystem>: Inject a custom ``Auth0Theme`` to match the SDK's colours, typography, spacing, corner radii, and component sizes to your brand — with zero configuration required for the default Auth0 look.
