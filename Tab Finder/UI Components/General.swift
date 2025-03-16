import SwiftUI
import AppKit

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String.LocalizationValue
    var font: NSFont = NSFont.systemFont(ofSize: 26)
    
    var placeholderColorDark: NSColor = .white.withAlphaComponent(0.3)
    var placeholderColorLight: NSColor = .black.withAlphaComponent(0.3)
    @Environment(\.colorScheme) private var colorScheme

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
            .foregroundColor: colorScheme == .dark ? placeholderColorDark : placeholderColorLight,
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
        nsView.stringValue = text
        nsView.placeholderAttributedString = getPlaceholderAttributedString()
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func _makeNSView() -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        _makeNSView()
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
