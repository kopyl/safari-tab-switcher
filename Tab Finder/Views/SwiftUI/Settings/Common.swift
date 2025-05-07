import SwiftUI

func styledText(_ text: String) -> some View {
    Text(text)
        .opacity(0.9)
        .font(.system(size: 14))
}

struct ToggleView: View {
    @Binding var isOn: Bool
    let text: String
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                styledText(text)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
        .tint(.white)
        .toggleStyle(.switch)
        .controlSize(.mini)
    }
}
