import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Platform-specific modifiers; each falls back to a working equivalent elsewhere.
extension View {
    /// Hides the system bar and back button so `LoginNavigationBar` can stand in.
    @ViewBuilder
    func systemNavigationBarHidden() -> some View {
        #if os(iOS) || os(visionOS)
        self.navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        #else
        self.navigationBarBackButtonHidden(true)
        #endif
    }

    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        #if os(visionOS)
        onChange(of: value) { _, newValue in action(newValue) }
        #else
        if #available(iOS 17, macOS 14, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
        #endif
    }

    /// Email keyboard, no autocorrect or autocapitalization.
    @ViewBuilder
    func emailInput() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        #else
        self
        #endif
    }

    /// No autocorrect or autocapitalization, for a code the user copied or wrote down.
    @ViewBuilder
    func secretInput() -> some View {
        #if os(iOS) || os(visionOS)
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        #else
        self.autocorrectionDisabled(true)
        #endif
    }

    /// Plain text for a username: no autocorrect or autocapitalization, offered to AutoFill as a username.
    @ViewBuilder
    func usernameInput() -> some View {
        #if os(iOS) || os(visionOS)
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.username)
        #else
        self.autocorrectionDisabled(true)
        #endif
    }

    /// A password: no autocorrect or autocapitalization, offered to AutoFill as a password.
    @ViewBuilder
    func passwordInput() -> some View {
        #if os(iOS) || os(visionOS)
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.password)
        #else
        self.autocorrectionDisabled(true)
        #endif
    }

    /// A drag on the scroll view dismisses the keyboard. visionOS has no such setting.
    @ViewBuilder
    func scrollDismissesKeyboardInteractively() -> some View {
        #if os(visionOS)
        self
        #else
        self.scrollDismissesKeyboard(.interactively)
        #endif
    }

    /// A scroll view that bounces only when its content is longer than the view, where the system allows it.
    @ViewBuilder
    func scrollBounceBasedOnSize() -> some View {
        if #available(iOS 16.4, macOS 13.3, visionOS 1.0, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    /// Has VoiceOver read `message` when it appears, since an error under a field is otherwise silent.
    func announcing(_ message: String?) -> some View {
        onChangeCompat(of: message) { newValue in
            #if canImport(UIKit)
            if let newValue { UIAccessibility.post(notification: .announcement, argument: newValue) }
            #endif
        }
    }

    /// Phone keypad, offering the user's own number for autofill.
    @ViewBuilder
    func phoneInput() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .autocorrectionDisabled(true)
        #else
        self
        #endif
    }
}
