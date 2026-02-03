import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if !os(macOS)
/// A UIKit-based OTP (one-time password) text input field for iOS and visionOS.
///
/// This text field is specialized for entering one-time passwords (OTP/MFA codes).
/// It displays one digit at a time and manages focus and input automatically.
/// Includes keyboard accessibility features and automatic dismissal on completion.
///
/// The field supports:
/// - Single digit per input
/// - Automatic focus management
/// - Enter key detection
/// - Backspace from empty field detection
struct OTPTextField: UIViewRepresentable {
    
    /// The complete OTP code being entered
    @Binding var fullText: String
    /// Position of this field in the OTP code (0-based index)
    var index: Int
    /// Total number of digits in the OTP code
    var digitCount: Int
    /// Callback when text is entered in this field
    var setText: ((String) -> Void)
    /// Callback when the enter/return key is pressed
    var enterKeyPressed: (() -> Void)
    /// Callback when backspace is pressed on an empty field
    var emptyBackspaceKeyPressed: (() -> Void)

    /// Creates the underlying UITextField for the OTP input.
    func makeUIView(context: Context) -> UITextField {
        let textField = BackSpaceTextField()
        textField.emptyBackspaceKeyPressed = emptyBackspaceKeyPressed
        textField.text = self.getText()
        textField.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.clearButtonMode = .never
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.tintColor = .gray
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: textField,
            action: #selector(UIResponder.resignFirstResponder)
        )
    
        toolbar.items = [flex, doneButton]
        #if !os(visionOS)
        textField.inputAccessoryView = toolbar
        #endif
        setSelection(textField)
        return textField
    }

    /// Updates the UITextField when the SwiftUI binding changes.
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = self.getText()
        self.setSelection(uiView)

        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        uiView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    /// Selects all text in the field.
    func setSelection(_ textField: UITextField) {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
    }

    /// Extracts the digit at this field's index from the full OTP text.
    func getText() -> String {
        if self.fullText.count <= self.index {
            return ""
        }
        return self.fullText.strAtIndex(self.index)
    }
}

extension OTPTextField {
    /// Creates the coordinator for handling UITextFieldDelegate callbacks.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Handles UITextFieldDelegate callbacks from the UITextField.
    class Coordinator: NSObject, UITextFieldDelegate {
        /// Reference to the parent OTPTextField
        var parent: OTPTextField
        /// Flag to track if text change event was triggered
        private var shouldChangeTriggered = false

        /// Initializes the coordinator with a reference to the parent field.
        init(_ control: OTPTextField) {
            self.parent = control
            super.init()
        }

        /// Called when the return/enter key is pressed.
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            self.parent.enterKeyPressed()
            return false
        }

        /// Called when editing begins, selects all text.
        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.parent.setSelection(textField)
        }

        /// Called when the text selection changes, maintains selection.
        func textFieldDidChangeSelection(_ textField: UITextField) {
            self.parent.setSelection(textField)
        }

        /// Handles character input, delegates to parent's setText callback.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            self.parent.setText(string)
            return false
        }
    }
}

/// Custom UITextField that detects backspace presses on empty fields.
class BackSpaceTextField: UITextField {
    /// Callback invoked when backspace is pressed while the field is empty
    var emptyBackspaceKeyPressed: (() -> Void)?

    /// Overrides deleteBackward to detect empty field backspace presses.
    override func deleteBackward() {
        if text?.isEmpty == true {
            emptyBackspaceKeyPressed?()
        }
        super.deleteBackward()
    }
}
#else

/// An AppKit-based OTP (one-time password) text input field for macOS.
///
/// This text field is specialized for entering one-time passwords (OTP/MFA codes) on macOS.
/// It displays one digit at a time and manages focus and input automatically.
///
/// The field supports:
/// - Single digit per input
/// - Automatic focus management
/// - Enter key detection
/// - Backspace from empty field detection
struct OTPTextField: NSViewRepresentable {
    /// The complete OTP code being entered
    @Binding var fullText: String
    /// Position of this field in the OTP code (0-based index)
    var index: Int
    /// Total number of digits in the OTP code
    var digitCount: Int
    /// Callback when text is entered in this field
    var setText: ((String) -> Void)
    /// Callback when the enter/return key is pressed
    var enterKeyPressed: (() -> Void)
    /// Callback when backspace is pressed on an empty field
    var emptyBackspaceKeyPressed: (() -> Void)

    /// Creates the underlying NSTextField for the OTP input.
    func makeNSView(context: Context) -> NSTextField {
        let textField = BackspaceAwareTextField()
        textField.emptyBackspaceKeyPressed = emptyBackspaceKeyPressed

        textField.stringValue = getText()
        textField.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        textField.alignment = .center

        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.focusRingType = .default
        textField.isBezeled = true
        textField.isEditable = true
        textField.isSelectable = true

        setSelection(textField)
        return textField
    }

    /// Updates the NSTextField when the SwiftUI binding changes.
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = getText()
        setSelection(nsView)
    }

    /// Selects all text in the field.
    func setSelection(_ textField: NSTextField) {
        guard !textField.stringValue.isEmpty else { return }
        if let editor = textField.currentEditor() {
            editor.selectedRange = NSMakeRange(0, textField.stringValue.count)
        }
    }

    /// Extracts the digit at this field's index from the full OTP text.
    func getText() -> String {
        if fullText.count <= index { return "" }
        return fullText[fullText.index(fullText.startIndex, offsetBy: index)].description
    }

    /// Creates the coordinator for handling NSTextFieldDelegate callbacks.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Handles NSTextFieldDelegate callbacks from the NSTextField.
    class Coordinator: NSObject, NSTextFieldDelegate {
        /// Reference to the parent OTPTextField
        var parent: OTPTextField

        /// Initializes the coordinator with a reference to the parent field.
        init(_ parent: OTPTextField) {
            self.parent = parent
        }

        /// Called when editing begins, selects all text.
        func controlTextDidBeginEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField { parent.setSelection(textField) }
        }

        /// Called when the text changes, delegates to parent's setText callback.
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }

            let newChar = textField.stringValue
            parent.setText(newChar)
            textField.stringValue = parent.getText()
            parent.setSelection(textField)
        }

        /// Handles keyboard commands including enter and delete/backspace.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {

            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.enterKeyPressed()
                return true
            }

            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if textView.string.isEmpty {
                    parent.emptyBackspaceKeyPressed()
                }
                return false
            }

            return false
        }
    }
}


/// Custom NSTextField that detects backspace presses on empty fields.
class BackspaceAwareTextField: NSTextField {
    /// Callback invoked when backspace is pressed while the field is empty
    var emptyBackspaceKeyPressed: (() -> Void)?

    /// Overrides keyDown to detect empty field backspace presses (key code 51).
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 {
            if stringValue.isEmpty {
                emptyBackspaceKeyPressed?()
            }
        }
        super.keyDown(with: event)
    }
}

#endif

/// String extension utilities for OTP field index management.
extension String {
    /// Returns the first N characters of the string.
    func prefix(length: Int) -> String {
        return String(self.prefix(length))
    }

    /// Returns the last N characters of the string.
    func suffix(length: Int) -> String {
        return String(self.suffix(length))
    }

    /// Returns the character at the specified index as a string.
    ///
    /// - Parameter int: The index of the character to retrieve
    /// - Returns: The character at the index, or empty string if out of bounds
    func strAtIndex(_ int: Int) -> String {
        if int >= self.count { return "" }
        let stringIndex = self.toStringIndex(int)
        return String(self[stringIndex])
    }

    /// Converts an integer index to a String.Index.
    ///
    /// - Parameter int: The integer offset
    /// - Returns: The corresponding String.Index, clamped to valid bounds
    func toStringIndex(_ int: Int) -> String.Index {
        if int <= 0 {
            return self.startIndex
        }
        if int >= self.count {
            return self.endIndex
        }
        return self.index(self.startIndex, offsetBy: int)
    }
}
