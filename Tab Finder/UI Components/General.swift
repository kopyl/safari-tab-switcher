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

struct CustomButtonStyle: ButtonStyle {
    enum StyleType {
        case primary, secondary
    }
    
    let type: StyleType
    let foregroundColor: Color
    let backgroundColor: Color
    let pressedColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .font(.system(size: 15, weight: .medium))
            .padding(12)
            .padding(.leading, 6)
            .foregroundColor(foregroundColor)
            .background(configuration.isPressed ? pressedColor : backgroundColor)
            .cornerRadius(7)
    }

    static var primary: CustomButtonStyle {
        CustomButtonStyle(
            type: .primary,
            foregroundColor: .white,
            backgroundColor: .blue,
            pressedColor: .black
        )
    }

    static var secondary: CustomButtonStyle {
        CustomButtonStyle(
            type: .secondary,
            foregroundColor: .blue,
            backgroundColor: .blue.opacity(0.11),
            pressedColor: .black
        )
    }
}

struct ButtonIcon: View {
    let icon: String
    let style: CustomButtonStyle

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(style.foregroundColor)
            .frame(width: 33, height: 25)
            .background(style.foregroundColor.opacity(0.17))
            .border(style.foregroundColor.opacity(0.21), width: 2)
            .cornerRadius(4)
    }
}

struct StyledButton: View {
    var style: CustomButtonStyle
    var title: String
    var icon: String
    var action: () -> Void

    init(
        _ style: CustomButtonStyle,
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                ButtonIcon(icon: icon, style: style)
            }
        }
        .buttonStyle(style)
    }
}
