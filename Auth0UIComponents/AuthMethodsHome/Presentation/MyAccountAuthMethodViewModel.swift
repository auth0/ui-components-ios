import Combine
import Auth0
import SwiftUI

/// View model for managing a single authentication method card's data and interactions.
///
/// `MyAccountAuthMethodViewModel` encapsulates the business logic for displaying and interacting
/// with a specific authentication method (TOTP, Push, Email, SMS, or Recovery Code) within the
/// authentication methods list. It provides the data needed for rendering the card and handles
/// navigation to enrollment or management screens.
///
/// ## Responsibilities
///
/// - **Data Provision**: Supplies display data (title, icon) for the authentication method card
/// - **Enrollment Status**: Determines if at least one factor is enrolled for this method type
/// - **Navigation Logic**: Decides appropriate destination based on method type and enrollment state
/// - **State Representation**: Acts as the single source of truth for one authentication method card
///
/// ## Architecture
///
/// Follows MVVM pattern:
/// - Used by `MyAccountAuthMethodView` for card rendering
/// - Coordinates with `NavigationStore` for navigation actions
/// - Wraps Auth0 `AuthenticationMethod` models with UI-specific logic
///
/// ## Navigation Behavior
///
/// The view model intelligently routes users based on context:
/// - **Enrolled Methods**: Navigates to management screen showing all enrolled instances
/// - **Unenrolled Methods**: Navigates to appropriate enrollment flow (QR code, email/phone input, recovery code generation)
///
/// ## Conformance
///
/// - **ObservableObject**: Enables SwiftUI view updates (though currently has no `@Published` properties)
/// - **Hashable**: Allows use in SwiftUI `ForEach` and collections, using method type as identity
///
/// ## Usage Example
///
/// ```swift
/// let viewModel = MyAccountAuthMethodViewModel(
///     authMethods: enrolledTOTPMethods,
///     type: .totp,
///     dependencies: .shared
/// )
///
/// MyAccountAuthMethodView(viewModel: viewModel)
/// ```
///
/// - Note: This view model is `final` to prevent subclassing and enable compiler optimizations.
final class MyAccountAuthMethodViewModel: ObservableObject {
    // MARK: - Properties

    /// Array of enrolled authentication methods for this specific method type.
    ///
    /// Contains all instances of this authentication method that the user has enrolled.
    /// For example, for TOTP type, this might include:
    /// - Google Authenticator on iPhone
    /// - Authy on Android tablet
    /// - Microsoft Authenticator on desktop
    ///
    /// Used to:
    /// - Determine enrollment status (empty = not enrolled, non-empty = enrolled)
    /// - Display list of enrolled methods in management screen
    /// - Pass to navigation destination for detailed management
    ///
    /// - Note: Filtered to this specific type before being passed to this view model.
    private let authMethods: [AuthenticationMethod]

    /// The type of authentication method this view model represents.
    ///
    /// Defines which authentication method type this card displays:
    /// - `.totp`: Authenticator apps (Google Authenticator, Authy, etc.)
    /// - `.pushNotification`: Push notifications via Auth0 Guardian
    /// - `.email`: Email-based one-time passwords
    /// - `.sms`: SMS-based one-time passwords
    /// - `.recoveryCode`: Backup recovery codes
    ///
    /// Used to determine:
    /// - Display title and icon via computed properties
    /// - Navigation destination for enrollment/management
    /// - Identity for Hashable conformance
    private let type: AuthMethodType

    /// SDK dependencies providing Auth0 configuration and services.
    ///
    /// Contains:
    /// - Auth0 domain and client ID
    /// - Token provider for credential management
    /// - Web authentication session configuration
    ///
    /// Currently stored for potential future use in navigation flows.
    private let dependencies: Auth0UIComponentsSDKInitializer

    // MARK: - Initialization

    /// Creates a new view model for a specific authentication method type.
    ///
    /// Initializes the view model with the enrolled methods data, method type identifier,
    /// and SDK configuration needed for displaying the card and handling interactions.
    ///
    /// ## Parameters
    ///
    /// - Parameter authMethods: Array of enrolled authentication methods for this type,
    ///   filtered to only include methods matching the `type` parameter
    /// - Parameter type: The authentication method type this view model represents
    /// - Parameter dependencies: SDK configuration for Auth0 integration
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // Filter methods to TOTP type
    /// let totpMethods = allMethods.filter { $0.type == "totp" }
    ///
    /// // Create view model for TOTP card
    /// let viewModel = MyAccountAuthMethodViewModel(
    ///     authMethods: totpMethods,
    ///     type: .totp,
    ///     dependencies: .shared
    /// )
    /// ```
    ///
    /// - Note: The `authMethods` array should be pre-filtered to match the `type` parameter
    ///   to ensure data consistency.
    init(authMethods: [AuthenticationMethod],
         type: AuthMethodType,
         dependencies: Auth0UIComponentsSDKInitializer) {
        self.authMethods = authMethods
        self.type = type
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    /// Determines if at least one authentication factor is confirmed/enrolled for this method type.
    ///
    /// Checks the enrolled authentication methods to see if any have been confirmed by the user.
    /// A confirmed method is one where the user has completed the enrollment process, including
    /// any required verification steps (e.g., verifying an OTP code).
    ///
    /// ## Use Cases
    ///
    /// - **UI Indicator**: Shows green checkmark on the card when true
    /// - **Navigation Logic**: Determines whether to navigate to management or enrollment screen
    /// - **Empty State**: Used to show "no methods enrolled" message when false for all types
    ///
    /// ## Confirmation Status
    ///
    /// A method is considered confirmed when:
    /// - User has completed the full enrollment flow
    /// - Verification code was successfully validated (for OTP methods)
    /// - Device was successfully paired (for TOTP/Push methods)
    /// - Recovery codes were generated and acknowledged
    ///
    /// ## Returns
    ///
    /// - `true`: At least one authentication method is confirmed/enrolled
    /// - `false`: No confirmed methods exist (either no enrollments or all are pending confirmation)
    ///
    /// ## Example
    ///
    /// ```swift
    /// if viewModel.isAtleastOnceAuthFactorEnrolled() {
    ///     // Show checkmark and navigate to management screen
    /// } else {
    ///     // Navigate to enrollment flow
    /// }
    /// ```
    func isAtleastOnceAuthFactorEnrolled() -> Bool {
        return authMethods.first(where: { $0.confirmed == true }) != nil
    }

    /// Returns the human-readable title for this authentication method type.
    ///
    /// Provides a user-friendly name for display in the authentication method card.
    /// The title is localized and appropriate for the method type.
    ///
    /// ## Returned Titles by Type
    ///
    /// - **TOTP**: "Authenticator App"
    /// - **Push**: "Push Notifications via Guardian"
    /// - **Email**: "Email OTP"
    /// - **SMS**: "SMS OTP"
    /// - **Recovery Code**: "Recovery Code"
    ///
    /// ## Returns
    ///
    /// A string representing the display name for this authentication method type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// Text(viewModel.title())
    ///     .font(.system(size: 16, weight: .medium))
    /// ```
    func title() -> String {
        type.title
    }

    /// Returns the image asset name for this authentication method type's icon.
    ///
    /// Provides the name of the image resource to display as the method's visual identifier
    /// in the authentication method card.
    ///
    /// ## Returned Image Names by Type
    ///
    /// - **TOTP**: "totp" (authenticator app icon)
    /// - **Push**: "totp" (shares icon with TOTP)
    /// - **Email**: "email" (envelope icon)
    /// - **SMS**: "sms" (phone/message icon)
    /// - **Recovery Code**: "code" (key/code icon)
    ///
    /// ## Returns
    ///
    /// A string representing the image asset name to be loaded from the resource bundle.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// Image(viewModel.image(), bundle: ResourceBundle.default)
    ///     .frame(width: 24, height: 24)
    /// ```
    ///
    /// - Note: The returned string is used with `ResourceBundle.default` to load the actual image.
    func image() -> String {
        type.image
    }

    /// Handles the tap gesture on the authentication method card, initiating appropriate navigation.
    ///
    /// This method is called when the user taps the authentication method card. It determines
    /// the appropriate navigation destination based on the method type and current enrollment
    /// status, then pushes that route to the navigation stack.
    ///
    /// ## Navigation Logic
    ///
    /// The destination is determined by:
    /// 1. **Enrollment Status**: Whether at least one factor is enrolled
    /// 2. **Method Type**: Which authentication method type this represents
    ///
    /// ### When Enrolled (has confirmed methods)
    /// Navigates to: **Saved Authenticators Screen**
    /// - Shows list of all enrolled instances
    /// - Allows viewing details and deleting specific methods
    /// - Useful when user has multiple devices/contacts enrolled
    ///
    /// ### When Not Enrolled (no confirmed methods)
    /// Navigates to appropriate enrollment flow:
    /// - **TOTP/Push**: QR code screen for device pairing
    /// - **Email/SMS**: Input form for entering email address or phone number
    /// - **Recovery Code**: Recovery code generation screen
    ///
    /// ## Threading
    ///
    /// Uses `Task` to execute the async navigation push on the main actor.
    /// The navigation store handles the actual routing and view transitions.
    ///
    /// ## Example Flow
    ///
    /// ```
    /// User taps TOTP card
    ///     ↓
    /// handleNavigation() called
    ///     ↓
    /// Check enrollment status
    ///     ↓
    /// ├─ Enrolled → Navigate to SavedAuthenticatorsScreen
    /// └─ Not Enrolled → Navigate to TOTPPushQRCodeView
    /// ```
    ///
    /// - Note: This method should only be called from the main thread/actor as it triggers UI navigation.
    func handleNavigation() {
        Task {
            // Determine destination route based on type and enrollment status
            await NavigationStore.shared.push(type.navigationDestination(authMethods))
        }
    }
}

// MARK: - Hashable Conformance

/// Extension providing Hashable conformance for MyAccountAuthMethodViewModel.
///
/// Enables the view model to be used in SwiftUI's `ForEach` with `id: \.self` and in
/// hash-based collections like `Set` and `Dictionary`. This is essential for SwiftUI's
/// view diffing algorithm to efficiently update the UI when the component array changes.
///
/// ## Implementation Details
///
/// - **Equality**: Two view models are considered equal if they represent the same authentication method type
/// - **Hashing**: Uses the enrolled authentication methods array to compute the hash value
///
/// ## Design Decision
///
/// The equality check uses only the `type` property, while hashing uses the `authMethods` array.
/// This design allows:
/// - Fast equality checks based on method type alone
/// - Unique hash values based on actual enrolled methods data
/// - Proper change detection when enrollment status changes
extension MyAccountAuthMethodViewModel: Hashable {
    /// Determines equality between two view model instances.
    ///
    /// Two view models are considered equal if they represent the same authentication method type,
    /// regardless of the enrolled methods or dependencies. This simplifies identity checking in
    /// SwiftUI's ForEach and ensures each method type appears once in the list.
    ///
    /// ## Parameters
    ///
    /// - Parameter lhs: The left-hand side view model to compare
    /// - Parameter rhs: The right-hand side view model to compare
    ///
    /// ## Returns
    ///
    /// `true` if both view models represent the same authentication method type, `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let totp1 = MyAccountAuthMethodViewModel(authMethods: methods1, type: .totp, dependencies: deps)
    /// let totp2 = MyAccountAuthMethodViewModel(authMethods: methods2, type: .totp, dependencies: deps)
    /// // totp1 == totp2 returns true (same type, even with different enrolled methods)
    /// ```
    static func == (lhs: MyAccountAuthMethodViewModel, rhs: MyAccountAuthMethodViewModel) -> Bool {
        lhs.type == rhs.type
    }

    /// Combines the view model's enrolled authentication methods into the hasher.
    ///
    /// Uses the array of authentication methods to generate a hash value, ensuring that
    /// changes in enrollment status or enrolled methods produce different hash values.
    /// This enables proper change detection in SwiftUI and hash-based collections.
    ///
    /// ## Parameter hasher
    ///
    /// An inout hasher to combine the authentication methods into
    ///
    /// ## Implementation Note
    ///
    /// While equality is based on type alone, hashing includes the enrolled methods array
    /// to ensure proper differentiation in hash-based collections and SwiftUI diffing.
    func hash(into hasher: inout Hasher) {
        hasher.combine(authMethods)
    }
}

// MARK: - AuthenticationMethod Hashable Conformance

/// Extension providing retroactive Hashable conformance for Auth0's AuthenticationMethod model.
///
/// Adds Hashable conformance to the Auth0 SDK's `AuthenticationMethod` type, which is required
/// for using these objects in SwiftUI's `ForEach` and hash-based collections. The `@retroactive`
/// attribute indicates this conformance is added to a type from another module.
///
/// ## Implementation
///
/// Uses the authentication method's unique `id` property for hashing, ensuring each
/// method instance has a unique hash value based on its server-assigned identifier.
///
/// ## Use Cases
///
/// - Enables `AuthenticationMethod` to be stored in `Set` or `Dictionary`
/// - Allows use in SwiftUI's `ForEach(id: \.self)` for rendering lists
/// - Required for the parent view model's `hash(into:)` implementation
extension AuthenticationMethod: @retroactive Hashable {
    /// Combines the authentication method's unique ID into the hasher.
    ///
    /// Uses the method's `id` property (assigned by Auth0 server) to generate a unique
    /// hash value for each authentication method instance.
    ///
    /// ## Parameter hasher
    ///
    /// An inout hasher to combine the method's ID into
    ///
    /// ## Implementation Note
    ///
    /// The `id` property is a unique identifier assigned by Auth0, ensuring each
    /// enrolled method has a distinct hash value even for the same method type.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - AuthMethodType Enum

/// Enumeration of supported authentication method types for multi-factor authentication.
///
/// `AuthMethodType` defines the different authentication methods that can be enrolled and managed
/// within the authentication system. Each case represents a distinct verification method with its
/// own enrollment flow, verification process, and user experience.
///
/// ## Supported Methods
///
/// - **email**: Email-based one-time passwords sent to user's email address
/// - **sms**: SMS-based one-time passwords sent to user's phone number
/// - **totp**: Time-based one-time passwords generated by authenticator apps (Google Authenticator, Authy, etc.)
/// - **pushNotification**: Push notifications via Auth0 Guardian app for mobile devices
/// - **recoveryCode**: Backup recovery codes for emergency account access
///
/// ## Raw Values
///
/// The enum uses `String` raw values that match Auth0's API response format:
/// - `email` → "email"
/// - `sms` → "phone" (Note: API uses "phone" while enum uses "sms")
/// - `totp` → "totp"
/// - `pushNotification` → "push-notification"
/// - `recoveryCode` → "recovery-code"
///
/// ## Conformance
///
/// - **String**: Raw representable with string values for API compatibility
/// - **CaseIterable**: Enables iteration over all cases for UI generation or testing
///
/// ## Usage Example
///
/// ```swift
/// // Initialize from API response
/// let methodType = AuthMethodType(rawValue: "totp") // .totp
///
/// // Iterate all supported methods
/// for method in AuthMethodType.allCases {
///     print(method.title) // User-friendly names
/// }
/// ```
///
/// - Note: The `sms` case has raw value "phone" to match Auth0's API format.
enum AuthMethodType: String, CaseIterable {
    /// Email-based one-time password authentication.
    /// Users receive verification codes via email.
    case email = "email"

    /// SMS-based one-time password authentication.
    /// Users receive verification codes via text message.
    /// Raw value is "phone" to match Auth0 API format.
    case sms = "phone"

    /// Time-based one-time password authentication using authenticator apps.
    /// Compatible with TOTP apps like Google Authenticator, Authy, Microsoft Authenticator.
    case totp = "totp"

    /// Push notification-based authentication via Auth0 Guardian app.
    /// Users approve authentication requests on their mobile device.
    case pushNotification = "push-notification"

    /// Backup recovery codes for emergency account access.
    /// Single-use codes generated for situations where primary methods are unavailable.
    case recoveryCode = "recovery-code"
}

// MARK: - AuthMethodType Extension

/// Extension providing computed properties for display strings and visual assets.
///
/// This extension adds UI-related properties to `AuthMethodType`, encapsulating all
/// user-facing strings and image names. This centralization ensures consistency across
/// the UI and makes localization easier in the future.
extension AuthMethodType {
    /// The primary display title for the authentication method.
    ///
    /// Returns a user-friendly name suitable for display in the main authentication methods list.
    /// These titles are concise and clearly identify the authentication method type.
    ///
    /// ## Returned Values
    ///
    /// - **email**: "Email OTP"
    /// - **sms**: "SMS OTP"
    /// - **totp**: "Authenticator App"
    /// - **pushNotification**: "Push Notifications via Guardian"
    /// - **recoveryCode**: "Recovery Code"
    ///
    /// ## Usage
    ///
    /// Used in `MyAccountAuthMethodView` to display the method name on each card.
    ///
    /// ```swift
    /// Text(authMethodType.title)
    ///     .font(.system(size: 16, weight: .medium))
    /// ```
    var title: String {
        switch self {
        case .email:
            "Email OTP"
        case .totp:
            "Authenticator App"
        case .pushNotification:
            "Push Notifications via Guardian"
        case .recoveryCode:
            "Recovery Code"
        case .sms:
            "SMS OTP"
        }
    }

    /// The image asset name for the authentication method's icon.
    ///
    /// Returns the name of the image resource to display for this method type in the UI.
    /// Some methods share the same icon (TOTP and Push both use "totp").
    ///
    /// ## Returned Values
    ///
    /// - **email**: "email" (envelope icon)
    /// - **sms**: "sms" (phone/message icon)
    /// - **totp**: "totp" (authenticator app icon)
    /// - **pushNotification**: "totp" (shares icon with TOTP)
    /// - **recoveryCode**: "code" (key/code icon)
    ///
    /// ## Usage
    ///
    /// Used with `ResourceBundle.default` to load the image asset in views.
    ///
    /// ```swift
    /// Image(authMethodType.image, bundle: ResourceBundle.default)
    ///     .frame(width: 24, height: 24)
    /// ```
    var image: String {
        switch self {
        case .email:
            "email"
        case .pushNotification,
                .totp:
            "totp"
        case .recoveryCode:
            "code"
        case .sms:
            "sms"
        }
    }

    /// Title text for individual cells in the saved authenticators list.
    ///
    /// Provides descriptive text for each enrolled method instance in the management screen.
    /// Similar to `title` but with slight variations for specific contexts.
    ///
    /// ## Returned Values
    ///
    /// - **email**: "Email OTP"
    /// - **sms**: "SMS OTP"
    /// - **totp**: "Authenticator App"
    /// - **pushNotification**: "Push Notifications via Guardian"
    /// - **recoveryCode**: "Recovery code generated"
    ///
    /// ## Usage
    ///
    /// Used in `SavedAuthenticatorsScreen` to label each enrolled method in the list.
    var savedAuthenticatorsCellTitle: String {
        switch self {
        case .email:
            "Email OTP"
        case .totp:
            "Authenticator App"
        case .pushNotification:
            "Push Notifications via Guardian"
        case .recoveryCode:
            "Recovery code generated"
        case .sms:
            "SMS OTP"
        }
    }

    /// The main heading title for the saved authenticators management screen.
    ///
    /// Returns a descriptive title for the screen showing all enrolled instances of this method type.
    /// Plural forms indicate that multiple instances can be enrolled.
    ///
    /// ## Returned Values
    ///
    /// - **email**: "Saved Emails for OTP"
    /// - **sms**: "Saved Phones for SMS OTP"
    /// - **totp**: "Saved Authenticators"
    /// - **pushNotification**: "Saved Apps for Push"
    /// - **recoveryCode**: "Generated Recovery code"
    ///
    /// ## Usage
    ///
    /// Used as the main heading in `SavedAuthenticatorsScreen` to describe the list content.
    ///
    /// ```swift
    /// Text(authMethodType.savedAuthenticatorsTitle)
    ///     .font(.system(size: 20, weight: .semibold))
    /// ```
    var savedAuthenticatorsTitle: String  {
        switch self {
        case .email:
            "Saved Emails for OTP"
        case .sms:
            "Saved Phones for SMS OTP"
        case .totp:
            "Saved Authenticators"
        case .pushNotification:
            "Saved Apps for Push"
        case .recoveryCode:
            "Generated Recovery code"
        }
    }

    /// The navigation bar title for the saved authenticators screen.
    ///
    /// Provides a concise title for the navigation bar when viewing enrolled methods.
    /// Shorter than `savedAuthenticatorsTitle` to fit navigation bar constraints.
    ///
    /// ## Returned Values
    ///
    /// - **email**: "Email OTP"
    /// - **sms**: "Phone for SMS OTP"
    /// - **totp**: "Authenticator"
    /// - **pushNotification**: "Push Notification"
    /// - **recoveryCode**: "Recovery Code"
    ///
    /// ## Usage
    ///
    /// Used with SwiftUI's `.navigationTitle()` modifier in `SavedAuthenticatorsScreen`.
    ///
    /// ```swift
    /// .navigationTitle(authMethodType.savedAuthenticatorsNavigationTitle)
    /// ```
    var savedAuthenticatorsNavigationTitle : String {
        switch self {
        case .pushNotification:
            "Push Notification"
        case .totp:
            "Authenticator"
        case .recoveryCode:
            "Recovery Code"
        case .email:
            "Email OTP"
        case .sms:
            "Phone for SMS OTP"
        }
    }

    /// The title for the confirmation dialog when managing an enrolled method.
    ///
    /// Returns the heading text for the action sheet or dialog that appears when users
    /// want to manage (view, edit, or delete) an enrolled authentication method.
    ///
    /// ## Returned Values
    ///
    /// - **email**: "Manage your email"
    /// - **sms**: "Manage your phone for SMS OTP"
    /// - **totp**: "Manage your Authenticator"
    /// - **pushNotification**: "Manage your Push Notification"
    /// - **recoveryCode**: "Manage your Recovery Code"
    ///
    /// ## Usage
    ///
    /// Used as the title in SwiftUI's `.confirmationDialog()` modifier.
    ///
    /// ```swift
    /// .confirmationDialog(
    ///     authMethodType.confirmationDialogTitle,
    ///     isPresented: $showDialog
    /// ) {
    ///     // Dialog buttons
    /// }
    /// ```
    var confirmationDialogTitle: String {
        switch self {
        case .pushNotification:
            "Manage your Push Notification"
        case .totp:
            "Manage your Authenticator"
        case .recoveryCode:
            "Manage your Recovery Code"
        case .email:
            "Manage your email"
        case .sms:
            "Manage your phone for SMS OTP"
        }
    }

    /// The destructive button label for removing/revoking an enrolled method.
    ///
    /// Returns the appropriate action verb for the destructive operation in the confirmation dialog.
    /// Different terms are used based on the permanence and nature of the removal:
    /// - **"Revoke"**: For device/app-based methods (implies permission withdrawal)
    /// - **"Remove"**: For contact-based and recovery methods (implies simple deletion)
    ///
    /// ## Returned Values
    ///
    /// - **email**: "Remove"
    /// - **sms**: "Remove"
    /// - **totp**: "Revoke"
    /// - **pushNotification**: "Revoke"
    /// - **recoveryCode**: "Remove"
    ///
    /// ## Usage
    ///
    /// Used for the destructive button in confirmation dialogs.
    ///
    /// ```swift
    /// Button(authMethodType.confirmationDialogDestructiveButtonTitle, role: .destructive) {
    ///     deleteMethod()
    /// }
    /// ```
    var confirmationDialogDestructiveButtonTitle: String {
        switch self {
        case .pushNotification:
            "Revoke"
        case .totp:
            "Revoke"
        case .recoveryCode,
                .email,
                .sms:
            "Remove"
        }
    }

    /// The empty state message when no methods of this type are enrolled.
    ///
    /// Returns a descriptive message to display when the saved authenticators screen is empty
    /// because the user hasn't enrolled any methods of this type yet.
    ///
    /// ## Returned Values
    ///
    /// - **email**: "No Email was saved."
    /// - **sms**: "No Phone was saved."
    /// - **totp**: "No Authenticator was added."
    /// - **pushNotification**: "No Push Notification was added."
    /// - **recoveryCode**: "No Recovery Code was generated."
    ///
    /// ## Usage
    ///
    /// Displayed in `SavedAuthenticatorsScreen` when the enrolled methods list is empty.
    ///
    /// ```swift
    /// if enrolledMethods.isEmpty {
    ///     Text(authMethodType.savedAuthenticatorsEmptyStateMessage)
    ///         .foregroundColor(.secondary)
    /// }
    /// ```
    var savedAuthenticatorsEmptyStateMessage: String {
        switch self {
        case .pushNotification:
            return "No Push Notification was added."
        case .email:
            return "No Email was saved."
        case .recoveryCode:
            return "No Recovery Code was generated."
        case .sms:
            return "No Phone was saved."
        case .totp:
            return "No Authenticator was added."
        }
    }
    

    // MARK: - Private Methods

    /// Checks if at least one authentication method is confirmed in the provided array.
    ///
    /// Internal helper method that determines enrollment status by searching for any
    /// confirmed authentication method in the given array. A method is confirmed when
    /// the user has completed the full enrollment and verification process.
    ///
    /// ## Parameters
    ///
    /// - Parameter authMethods: Array of authentication methods to check for confirmation status
    ///
    /// ## Returns
    ///
    /// - `true`: At least one method has `confirmed == true`
    /// - `false`: No confirmed methods exist (empty array or all unconfirmed)
    ///
    /// ## Usage
    ///
    /// Used internally by `navigationDestination(_:)` to determine the appropriate route.
    ///
    /// - Note: This is a private helper method. Public consumers should use the class-level
    ///   `isAtleastOnceAuthFactorEnrolled()` method instead.
    private func isAtleastOnceAuthFactorEnrolled(_ authMethods: [AuthenticationMethod]) -> Bool {
        return authMethods.first(where: { $0.confirmed == true }) != nil
    }

    // MARK: - Public Methods

    /// Determines the appropriate navigation destination based on enrollment status and method type.
    ///
    /// This method implements the core navigation logic for authentication method cards,
    /// intelligently routing users to either the enrollment flow (for new methods) or the
    /// management screen (for already-enrolled methods).
    ///
    /// ## Navigation Decision Logic
    ///
    /// The routing follows this decision tree:
    ///
    /// ```
    /// Has confirmed enrollment?
    ///     ├─ YES → Navigate to SavedAuthenticatorsScreen (management)
    ///     └─ NO  → Navigate to appropriate enrollment flow:
    ///                ├─ TOTP/Push → QR Code Screen
    ///                ├─ Email → Email Input Screen
    ///                ├─ SMS → Phone Input Screen
    ///                └─ Recovery Code → Code Generation Screen
    /// ```
    ///
    /// ## Enrollment Flow Routes
    ///
    /// ### TOTP & Push (.totpPushQRScreen)
    /// - Displays QR code for device/app pairing
    /// - User scans with authenticator app (Google Authenticator, Authy, etc.)
    /// - Leads to OTP verification screen
    ///
    /// ### Email (.emailPhoneEnrollmentScreen with .email)
    /// - Input form for email address
    /// - Validation and verification code sending
    /// - Leads to OTP verification screen
    ///
    /// ### SMS (.emailPhoneEnrollmentScreen with .sms)
    /// - Input form for phone number with country code selector
    /// - Validation and verification code sending via SMS
    /// - Leads to OTP verification screen
    ///
    /// ### Recovery Code (.recoveryCodeScreen)
    /// - Generates set of single-use backup codes
    /// - Displays codes with copy/download options
    /// - User must acknowledge and save codes
    ///
    /// ## Management Flow Route
    ///
    /// ### Enrolled Methods (.filteredAuthListScreen)
    /// - Lists all enrolled instances of this method type
    /// - Shows details (email address, phone number, device name, etc.)
    /// - Provides delete/revoke options for each instance
    /// - Useful when user has multiple devices or contacts enrolled
    ///
    /// ## Parameters
    ///
    /// - Parameter authMethods: Array of enrolled authentication methods for this type
    ///
    /// ## Returns
    ///
    /// A `Route` enum value representing the navigation destination, containing all necessary
    /// data for the destination screen.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let destination = AuthMethodType.totp.navigationDestination(enrolledMethods)
    /// // If enrolled: .filteredAuthListScreen(type: .totp, authMethods: enrolledMethods)
    /// // If not enrolled: .totpPushQRScreen(type: .totp)
    /// ```
    ///
    /// - Note: This method is called internally by `MyAccountAuthMethodViewModel.handleNavigation()`.
    func navigationDestination(_ authMethods: [AuthenticationMethod]) -> Route {
        // Check if user has at least one confirmed method of this type
        if isAtleastOnceAuthFactorEnrolled(authMethods) == true {
           // User has enrolled - navigate to management screen
           return .filteredAuthListScreen(type: self, authMethods: authMethods)
        } else {
            // User hasn't enrolled - navigate to appropriate enrollment flow
            switch self {
            case .pushNotification,
                    .totp:
               // TOTP and Push use QR code enrollment
               return .totpPushQRScreen(type: self)
            case .email:
               // Email uses input form with email type
               return .emailPhoneEnrollmentScreen(type: .email)
            case .sms:
               // SMS uses input form with phone type
               return .emailPhoneEnrollmentScreen(type: self)
            case .recoveryCode:
               // Recovery codes use generation screen
               return .recoveryCodeScreen
            }
        }
    }
}
