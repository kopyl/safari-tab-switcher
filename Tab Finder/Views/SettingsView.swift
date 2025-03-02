import SwiftUI

let description = """
When enabled, the tabs panel won't disappear when you release the Option key.
To switch to a tab, just press Return or select the tab with your mouse.
"""

struct SettingsView: View {
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Toggle("Keep tab switcher open", isOn: $isTabsSwitcherNeededToStayOpen)
            }
            Spacer()
            Text(description)
                .opacity(0.7)
        }
        .frame(width: 300, height: 150, alignment: .topLeading)
        .padding(20)
    }
}
