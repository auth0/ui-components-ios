import SwiftUI

/// Values from the factor screens' Figma frames (393 pt wide) that have no theme token yet.
enum FactorScreenStyle {
    /// Inter Regular 18 pt: screen and outcome titles.
    static var title: Auth0TextStyle { style("Inter-Regular", 18, .title3, lineSpacing: 6) }
    /// Inter Regular 16 pt: the waiting screen's subtitle.
    static var waitingSubtitle: Auth0TextStyle { style("Inter-Regular", 16, .callout, lineSpacing: 3) }
    /// Inter Medium 15 pt: "Verify another way".
    static var action: Auth0TextStyle { style("Inter-Medium", 15, .subheadline, lineSpacing: 0) }

    static let waitingTop: CGFloat = 14
    static let waitingTitleGap: CGFloat = 11
    static let spinnerTop: CGFloat = 96
    static let spinnerDiameter: CGFloat = 44
    static let actionsTop: CGFloat = 59
    static let outcomeMessageTop: CGFloat = 19
    static let rowIconSize: CGFloat = 22
    static let rowLeading: CGFloat = 18

    private static func style(_ name: String, _ size: CGFloat, _ relativeTo: Font.TextStyle,
                              lineSpacing: CGFloat) -> Auth0TextStyle {
        Auth0FontRegistration.registerIfNeeded()
        return Auth0TextStyle(font: .custom(name, size: size, relativeTo: relativeTo), lineSpacing: lineSpacing)
    }
}
