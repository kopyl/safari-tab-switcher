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

struct OnboardingButtonStyle: ButtonStyle {
    var foregroundColor = Color.white
    var backgroundColor = Color.blue
    var pressedColor = Color.black

  func makeBody(configuration: Self.Configuration) -> some View {
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

struct OnboardingButton: View {
    var startUsingTabFinder: () -> Void
    
    init(startUsingTabFinder: @escaping () -> Void ) {
        self.startUsingTabFinder = startUsingTabFinder
    }
    
    var body: some View {
        Button(Copy.Onboarding.button) {
            startUsingTabFinder()
        }
        .buttonStyle(OnboardingButtonStyle())
    }
}
