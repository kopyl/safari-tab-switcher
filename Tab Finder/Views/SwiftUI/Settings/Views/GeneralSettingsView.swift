import SwiftUI

struct GeneralSettingsView: View {
    
    @AppStorage(
        Store.moveAppOutOfBackgroundWhenSafariClosesStoreKey,
        store: Store.userDefaults
    ) private var moveAppOutOfBackgroundWhenSafariCloses: Bool = Store.moveAppOutOfBackgroundWhenSafariClosesDefaultValue
    
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack {
            ToggleView(isOn: !$moveAppOutOfBackgroundWhenSafariCloses, text: "Keep app in background when Safari closes")
        }
        .padding(.top, 10)
        .padding(.horizontal, 30)
        Spacer()
        .frame(minWidth: 444, maxWidth: 444, minHeight: 340, maxHeight: 340)
    }
}
