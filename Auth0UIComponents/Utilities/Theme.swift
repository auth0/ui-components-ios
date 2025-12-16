import Foundation
import SwiftUI

public struct Auth0UIComponentGlobalTheme {
    public let backgroundColor: Color
    public let titeTheme: TextTheme
    public let title2Theme: TextTheme
    public let title3Theme: TextTheme
    public let buttonTheme: ButtonTheme
    public let successToastTheme: ToastTheme
    public let errorToastTheme: ToastTheme
    public let infoToastTheme: ToastTheme
    public let otpTextFieldTheme: OTPTextFieldTheme
    
    public init(backgroundColor: Color, titeTheme: TextTheme, title2Theme: TextTheme, title3Theme: TextTheme, buttonTheme: ButtonTheme, successToastTheme: ToastTheme, errorToastTheme: ToastTheme, infoToastTheme: ToastTheme, otpTextFieldTheme: OTPTextFieldTheme) {
        self.backgroundColor = backgroundColor
        self.titeTheme = titeTheme
        self.title2Theme = title2Theme
        self.title3Theme = title3Theme
        self.buttonTheme = buttonTheme
        self.successToastTheme = successToastTheme
        self.errorToastTheme = errorToastTheme
        self.infoToastTheme = infoToastTheme
        self.otpTextFieldTheme = otpTextFieldTheme
    }
}

public struct Auth0UIComponentCustomTheme {
    public let myAccountAuthTheme: MyAccountAuthMethodTheme
    public let qrTheme: QRTheme
    public let recoveryCodeTheme: RecoveryCodeTheme
    public let enrolledFactorsTheme: EnrolledFactorsTheme
    public let otpTheme: OTPTheme
    
    public init(myAccountAuthTheme: MyAccountAuthMethodTheme, qrTheme: QRTheme, recoveryCodeTheme: RecoveryCodeTheme, enrolledFactorsTheme: EnrolledFactorsTheme, otpTheme: OTPTheme) {
        self.myAccountAuthTheme = myAccountAuthTheme
        self.qrTheme = qrTheme
        self.recoveryCodeTheme = recoveryCodeTheme
        self.enrolledFactorsTheme = enrolledFactorsTheme
        self.otpTheme = otpTheme
    }
}

public struct MyAccountAuthMethodTheme {
    public let navTheme: NavTheme
    public let backgroundColor: Color
    public let title2Theme: TextTheme
    public let cellTheme: MyAccountAuthCellTheme
    
    public init(navTheme: NavTheme, backgroundColor: Color, title2Theme: TextTheme, cellTheme: MyAccountAuthCellTheme) {
        self.navTheme = navTheme
        self.backgroundColor = backgroundColor
        self.title2Theme = title2Theme
        self.cellTheme = cellTheme
    }
}

public struct MyAccountAuthCellTheme {
    public let cornerRadius: CGFloat
    public let backgroundColor: Color
    public let borderColor: Color
    public let borderWidth: CGFloat
    public let title2Theme: TextTheme
    public let title3Theme: TextTheme
    
    public init(cornerRadius: CGFloat, backgroundColor: Color, borderColor: Color, borderWidth: CGFloat, title2Theme: TextTheme, title3Theme: TextTheme) {
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.title2Theme = title2Theme
        self.title3Theme = title3Theme
    }
}

public struct QRTheme {
    public let navTheme: NavTheme
    public let copyTextTheme: CopyTextTheme
    
    public init(navTheme: NavTheme, copyTextTheme: CopyTextTheme) {
        self.navTheme = navTheme
        self.copyTextTheme = copyTextTheme
    }
}

public struct RecoveryCodeTheme {
    public let navTheme: NavTheme
    public let copyTextTheme: CopyTextTheme
    public let backgroundColor: Color
    
    public init(navTheme: NavTheme, copyTextTheme: CopyTextTheme, backgroundColor: Color) {
        self.navTheme = navTheme
        self.copyTextTheme = copyTextTheme
        self.backgroundColor = backgroundColor
    }
}

public struct NavTheme {
    public let titleColor: Color
    public let titleFont: Font
    
    public init(titleColor: Color, titleFont: Font) {
        self.titleColor = titleColor
        self.titleFont = titleFont
    }
}

public struct CellTitleTheme {
    public let titleColor: Color
    public let titleFont: Font
    public let backgroundColor: Color
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let borderWidth: CGFloat
    
    public init(titleColor: Color, titleFont: Font, backgroundColor: Color, cornerRadius: CGFloat, borderColor: Color, borderWidth: CGFloat) {
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

public struct CopyTextTheme {
    public let titleColor: Color
    public let titleFont: Font
    public let backgroundColor: Color
    public let borderColor: Color
    public let cornerRadius: CGFloat
    
    public init(titleColor: Color, titleFont: Font, backgroundColor: Color, borderColor: Color, cornerRadius: CGFloat) {
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
    }
}

public struct EnrolledFactorsTheme {
    public let navTheme: NavTheme
    public let backgroundColor: Color
    public let cellTheme: EnrolledFactorsCellTheme
    
    public init(navTheme: NavTheme, backgroundColor: Color, cellTheme: EnrolledFactorsCellTheme) {
        self.navTheme = navTheme
        self.backgroundColor = backgroundColor
        self.cellTheme = cellTheme
    }
}

public struct EnrolledFactorsCellTheme {
    public let titleColor: Color
    public let titleFont: Font
    public let backgroundColor: Color
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let borderWidth: CGFloat
    
    public init(titleColor: Color, titleFont: Font, backgroundColor: Color, cornerRadius: CGFloat, borderColor: Color, borderWidth: CGFloat) {
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

public struct OTPTheme {
    public let navTheme: NavTheme
    public let backgroundColor: Color
    public let titleTheme: TextTheme
    public let otpTextFieldTheme: OTPTextFieldTheme
    
    public init(navTheme: NavTheme, backgroundColor: Color, titleTheme: TextTheme, otpTextFieldTheme: OTPTextFieldTheme) {
        self.navTheme = navTheme
        self.backgroundColor = backgroundColor
        self.titleTheme = titleTheme
        self.otpTextFieldTheme = otpTextFieldTheme
    }
}

public struct OTPTextFieldTheme {
    public let highlightColor: Color
    public let normalColor: Color
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let borderWidth: CGFloat
    public let textTheme: TextTheme
    
    public init(highlightColor: Color, normalColor: Color, cornerRadius: CGFloat, borderColor: Color, borderWidth: CGFloat, textTheme: TextTheme) {
        self.highlightColor = highlightColor
        self.normalColor = normalColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.textTheme = textTheme
    }
}

public struct TextTheme {
    public let color: Color
    public let font: Font
    
    public init(color: Color, font: Font) {
        self.color = color
        self.font = font
    }
}

public struct ButtonTheme {
    public let backgroundColor: Color
    public let textTheme: TextTheme
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let borderWidth: CGFloat
    
    public init(backgroundColor: Color, textTheme: TextTheme, cornerRadius: CGFloat, borderColor: Color, borderWidth: CGFloat) {
        self.backgroundColor = backgroundColor
        self.textTheme = textTheme
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

public struct ToastTheme {
    public let backgroundColor: Color
    public let textTheme: TextTheme
    public let cornerRadius: CGFloat
    
    public init(backgroundColor: Color, textTheme: TextTheme, cornerRadius: CGFloat) {
        self.backgroundColor = backgroundColor
        self.textTheme = textTheme
        self.cornerRadius = cornerRadius
    }
}

public struct Auth0UIComponentGlobalThemeKey: EnvironmentKey {
    static public let defaultValue: Auth0UIComponentGlobalTheme? = nil
}

public struct Auth0UIComponentCustomThemeKey: EnvironmentKey {
    static public let defaultValue: Auth0UIComponentCustomTheme? = nil
}

public extension EnvironmentValues {
    var globalTheme: Auth0UIComponentGlobalTheme? {
        get { self[Auth0UIComponentGlobalThemeKey.self] }
        set { self[Auth0UIComponentGlobalThemeKey.self] = newValue }
    }
    
    var customTheme: Auth0UIComponentCustomTheme? {
        get { self[Auth0UIComponentCustomThemeKey.self] }
        set { self[Auth0UIComponentCustomThemeKey.self] = newValue }
    }
}
