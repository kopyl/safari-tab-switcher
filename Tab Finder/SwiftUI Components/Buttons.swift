import SwiftUI

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
