import SwiftUI
import KeyboardShortcuts

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

extension NSEvent.ModifierFlags {
    var symbolRepresentation: String {
        var symbols = ""

        if contains(.command) {
            symbols += "⌘"
        }
        if contains(.option) {
            symbols += "⌥"
        }
        if contains(.control) {
            symbols += "⌃"
        }
        if contains(.shift) {
            symbols += "⇧"
        }
        if contains(.capsLock) {
            symbols += "⇪"
        }

        return symbols
    }
}

struct SettingsView: View {
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = false
    
    @State
    var shortcutModifiers =
    KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers.symbolRepresentation
    
    @ObservedObject var appState: AppState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 120) {
            Toggle(isOn: !$isTabsSwitcherNeededToStayOpen) {
                HStack {
                    Text("Close tabs list when \(shortcutModifiers ?? "Option") is released")
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
            HStack {
                Text(
                    isFocused ?
                    "Press your desired shortcut to open tabs list"
                    :
                    "Shortcut for opening tabs list"
                )
                    .opacity(0.8)
                    .font(.system(size: 15))
                Spacer()
                KeyboardShortcuts.Recorder(for: .openTabsList)
                    .focused($isFocused)
                    .onChange(of: isFocused) {
                        appState.isShortcutRecorderNeedsToBeFocused = $0
                    }
                    .onChange(of: appState.isShortcutRecorderNeedsToBeFocused) { newValue in
                        DispatchQueue.main.async {
                            isFocused = newValue
                        }
                    }
                    .task {
                        isFocused = appState.isShortcutRecorderNeedsToBeFocused
                    }
            }
        }
        .padding(.top, 42)
        .padding(.bottom, 54)
        .padding(.horizontal, 30)
    }
}
