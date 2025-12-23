import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if !os(macOS)
struct OTPTextField: UIViewRepresentable {
    
    @Binding var fullText: String

    var index: Int
    var digitCount: Int
    var setText: ((String) -> Void)
    var enterKeyPressed: (() -> Void)
    var emptyBackspaceKeyPressed: (() -> Void)

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

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = self.getText()
        self.setSelection(uiView)
        
        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        uiView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    
    
    func setSelection(_ textField: UITextField) {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
    }
    
    func getText() -> String {
        if self.fullText.count <= self.index {
            return ""
        }
        return self.fullText.strAtIndex(self.index)
    }
}

extension OTPTextField {
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OTPTextField
        
        private var shouldChangeTriggered = false

        init(_ control: OTPTextField) {
            self.parent = control
            super.init()
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            self.parent.enterKeyPressed()
            return false
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.parent.setSelection(textField)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            self.parent.setSelection(textField)
        }
        
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            self.parent.setText(string)
            return false
        }
    }
}


class BackSpaceTextField: UITextField {
    var emptyBackspaceKeyPressed: (() -> Void)?

    override func deleteBackward() {
        if text?.isEmpty == true {
            emptyBackspaceKeyPressed?()
        }
        super.deleteBackward()
    }
}
#else

struct OTPTextField: NSViewRepresentable {

    @Binding var fullText: String

    var index: Int
    var digitCount: Int
    var setText: ((String) -> Void)
    var enterKeyPressed: (() -> Void)
    var emptyBackspaceKeyPressed: (() -> Void)

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

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = getText()
        setSelection(nsView)
    }

    func setSelection(_ textField: NSTextField) {
        guard !textField.stringValue.isEmpty else { return }
        if let editor = textField.currentEditor() {
            editor.selectedRange = NSMakeRange(0, textField.stringValue.count)
        }
    }

    func getText() -> String {
        if fullText.count <= index { return "" }
        return fullText[fullText.index(fullText.startIndex, offsetBy: index)].description
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OTPTextField

        init(_ parent: OTPTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField { parent.setSelection(textField) }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }

            let newChar = textField.stringValue
            parent.setText(newChar)
            textField.stringValue = parent.getText()   // Keep 1 char only
            parent.setSelection(textField)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {

            // ENTER key
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.enterKeyPressed()
                return true
            }

            // BACKSPACE on empty
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


// MARK: - Custom NSTextField for detecting empty backspace
class BackspaceAwareTextField: NSTextField {
    var emptyBackspaceKeyPressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 { // delete key
            if stringValue.isEmpty {
                emptyBackspaceKeyPressed?()
            }
        }
        super.keyDown(with: event)
    }
}

#endif
extension String {

    func _prefix(_ length: Int) -> String {
        return String(self.prefix(length))
    }
    func _suffix(_ length: Int) -> String {
        return String(self.suffix(length))
    }
    
    func strAtIndex(_ int: Int) -> String {
        if int >= self.count { return "" }
        let stringIndex = self.toStringIndex(int)
        return String(self[stringIndex])
    }

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
