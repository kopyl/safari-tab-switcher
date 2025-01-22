import SwiftUI
import AppKit

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String.LocalizationValue
    var placeholderColor: NSColor = NSColor.gray
    var font: NSFont = NSFont.systemFont(ofSize: 26)

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField

        init(parent: CustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func getPlaceholderAttributedString() -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeholderColor,
            .font: font,
        ]
        let inflected = AttributedString(localized: placeholder)
        let inflectedStr = String(inflected.characters)
        return NSAttributedString(string: inflectedStr, attributes: attributes)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isBezeled = false
        textField.isBordered = false
        textField.backgroundColor = nil

        textField.focusRingType = .none
        textField.font = font
        
        textField.isEditable = true
        textField.isSelectable = true
        textField.delegate = context.coordinator

        textField.placeholderAttributedString = getPlaceholderAttributedString()

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        let selectedRange = NSRange(location: nsView.stringValue.count+1, length: 0)
        
        nsView.stringValue = text
        nsView.placeholderAttributedString = getPlaceholderAttributedString()

        guard let editor = nsView.currentEditor() else { return }
        editor.selectedRange = selectedRange
    }
}
