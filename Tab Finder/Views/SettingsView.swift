import SwiftUI

let description = """
When enabled, the tabs panel won't disappear when you release the Option key.
To switch to a tab, just press Return or select the tab with your mouse.
"""

prefix func ! (value: Binding<Bool>) -> Binding<Bool> {
    Binding<Bool>(
        get: { !value.wrappedValue },
        set: { value.wrappedValue = !$0 }
    )
}

struct SettingsView: View {
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: !$isTabsSwitcherNeededToStayOpen) {
                HStack {
                    Text("Close tabs list when Option key is released")
                        .opacity(0.8)
                        .font(.system(size: 15))
                    Spacer()
                }
            }
            .contentShape(Rectangle())	
            .onTapGesture {
                isTabsSwitcherNeededToStayOpen.toggle()
            }
            .tint(.white)
            .keyboardShortcut(.space, modifiers: [])
            .toggleStyle(.switch)
        }
        .padding(.top, 42)
        .padding(.bottom, 63)
        .padding(.horizontal, 30)
    }
}
