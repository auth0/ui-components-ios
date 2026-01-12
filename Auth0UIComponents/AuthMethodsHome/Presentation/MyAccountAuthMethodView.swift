import SwiftUI

/// An interactive card view representing a single authentication method (TOTP, Push, Email, SMS, or Recovery Code).
///
/// `MyAccountAuthMethodView` displays a tappable card for each authentication method, showing:
/// - Method icon (authenticator app, email envelope, phone, etc.)
/// - Method name (e.g., "Authenticator App", "Email", "SMS")
/// - Enrollment status indicator (checkmark if enrolled)
/// - Navigation chevron to indicate tappability
///
/// ## Visual Structure
///
/// The card uses a horizontal layout with the following elements from left to right:
/// 1. **Method Icon** (24x24): Visual identifier for the authentication type
/// 2. **Method Title**: Human-readable name of the authentication method
/// 3. **Spacer**: Pushes remaining elements to the right
/// 4. **Enrollment Indicator** (conditional): Green checkmark shown when at least one factor is enrolled
/// 5. **Chevron Icon** (16x16): Right-pointing arrow indicating navigation
///
/// ## Interaction
///
/// - **Tap Gesture**: Triggers navigation handled by the view model
/// - Navigation destinations vary based on method type and enrollment status:
///   - Enrolled methods: Navigate to management/deletion screen
///   - Unenrolled methods: Navigate to enrollment flow
///
/// ## Styling
///
/// - **Border**: 1pt light gray rounded rectangle with 16pt corner radius
/// - **Padding**: 20pt on all sides for comfortable touch target
/// - **Typography**: 16pt medium weight system font
/// - **Color Scheme**: Black text, light gray border, green checkmark
///
/// ## Architecture
///
/// Follows MVVM pattern:
/// - View layer: Handles layout and visual presentation
/// - ViewModel (`MyAccountAuthMethodViewModel`): Provides data and handles business logic
///
/// ## Usage Example
///
/// ```swift
/// MyAccountAuthMethodView(viewModel: MyAccountAuthMethodViewModel(
///     authMethods: enrolledMethods,
///     type: .totp,
///     dependencies: dependencies
/// ))
/// ```
///
/// - Note: This view is typically used within a `ForEach` loop in the parent
///   `MyAccountAuthMethodsView`, rendering one card per available authentication method.
struct MyAccountAuthMethodView: View {
    // MARK: - Properties

    /// View model containing the authentication method's data and business logic.
    ///
    /// Provides:
    /// - Method icon name for image lookup
    /// - Method title text for display
    /// - Enrollment status for conditional UI rendering
    /// - Navigation handling when card is tapped
    ///
    /// Uses `@ObservedObject` to react to published property changes from the view model.
    @ObservedObject var viewModel: MyAccountAuthMethodViewModel

    // MARK: - Body

    /// The main view hierarchy composing the authentication method card.
    ///
    /// Constructs a horizontally laid-out card with method icon, title, enrollment indicator,
    /// and navigation chevron. The entire card is tappable and triggers navigation via the
    /// view model when tapped.
    ///
    /// ## Layout Structure
    ///
    /// ```
    /// ┌─────────────────────────────────────────────┐
    /// │  [Icon]  Method Name      [✓]  [>]          │
    /// └─────────────────────────────────────────────┘
    /// ```
    ///
    /// - The checkmark (✓) only appears when the method has enrolled factors
    /// - All elements are vertically centered within the card
    /// - The card has a light gray border and rounded corners
    ///
    /// ## Interactive Behavior
    ///
    /// The entire card responds to tap gestures, triggering the view model's
    /// `handleNavigation()` method which determines the appropriate navigation
    /// destination based on the method type and enrollment state.
    var body: some View {
        HStack() {
            // MARK: Method Icon
            // Displays the visual identifier for the authentication method type
            // (e.g., authenticator app icon, email icon, phone icon, recovery code icon)
            Image(viewModel.image(), bundle: ResourceBundle.default)
                .frame(width: 24, height: 24) // Fixed size for consistent card height
                .padding(.trailing, 16) // Spacing between icon and title

            // MARK: Method Title
            // Human-readable name of the authentication method
            // Examples: "Authenticator App", "Email", "SMS", "Recovery Code"
            Text(viewModel.title())
                .font(.system(size: 16, weight: .medium)) // Medium weight for emphasis
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default)) // Pure black for readability
                .padding(.trailing, 16) // Spacing after title

            // Push remaining elements to the right side of the card
            Spacer()

            // MARK: Enrollment Status Indicator
            // Conditionally displays a green checkmark when user has enrolled this method
            // Provides quick visual feedback about enrollment status without reading text
            if viewModel.isAtleastOnceAuthFactorEnrolled() {
                Image("checkmark.green", bundle: ResourceBundle.default)
                    .frame(width: 24, height: 24) // Matches icon size for visual balance
                    .padding(.trailing, 22) // Spacing before chevron
            }

            // MARK: Navigation Chevron
            // Right-pointing arrow indicating the card is tappable and will navigate
            // Standard iOS pattern for tappable rows/cards that lead to detail screens
            Image("chevron", bundle: ResourceBundle.default)
                .frame(width: 16, height: 16) // Smaller than method icon for hierarchy
        }
        .padding(.all, 20) // Internal padding for comfortable touch target (min 44x44pt iOS guideline)
        .overlay {
            // MARK: Card Border
            // Light gray border defining the card boundaries with rounded corners
            // Creates visual separation between multiple method cards in the list
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
        }
        .onTapGesture {
            // MARK: Tap Handler
            // Triggers navigation when user taps anywhere on the card
            // View model determines destination based on method type and enrollment status:
            // - Enrolled: Navigate to management screen (view/delete enrolled methods)
            // - Not enrolled: Navigate to enrollment flow (QR code, OTP, email/phone input)
            viewModel.handleNavigation()
        }
    }
}
