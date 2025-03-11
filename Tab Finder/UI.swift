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

struct CustomButtonStyle: ButtonStyle {
    var foregroundColor: Color
    var backgroundColor: Color
    var pressedColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .font(.system(size: 16))
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .foregroundColor(foregroundColor)
            .background(configuration.isPressed ? pressedColor : backgroundColor)
            .cornerRadius(7)
    }
}

extension ButtonStyle where Self == CustomButtonStyle {
    static var primary: CustomButtonStyle {
        CustomButtonStyle(
            foregroundColor: .white,
            backgroundColor: .blue,
            pressedColor: .black
        )
    }

    static var secondary: CustomButtonStyle {
        CustomButtonStyle(
            foregroundColor: .blue,
            backgroundColor: .blue.opacity(0.06),
            pressedColor: .black
        )
    }
}

struct StyledButton<S: ButtonStyle>: View {
    var title: String
    var style: S
    var action: () -> Void

    init(_ style: S, _ title: String, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(style)
    }
}
