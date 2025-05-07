import SwiftUI
import KeyboardShortcuts

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

extension NSEvent {
    var appShortcutIsPressed: Bool {
        modifierFlags.contains(.command) && AppShortcutKeys(rawValue: keyCode) != nil
    }
    
    var shiftIsHolding: Bool {
        modifierFlags.contains(.shift)
    }
}

struct ShortcutSettingsView: View {
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = true
    
    @AppStorage(
        Store.addStatusBarItemWhenAppMovesInBackgroundStoreKey,
        store: Store.userDefaults
    ) private var addStatusBarItemWhenAppMovesInBackground: Bool = Store.addStatusBarItemWhenAppMovesInBackgroundDefaultValue
    
    @State
    var shortcutModifiers =
    KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers.symbolRepresentation
    
    @ObservedObject var appState: AppState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 46) {
            ToggleView(isOn: !$isTabsSwitcherNeededToStayOpen, text: "Close tabs list when \(shortcutModifiers ?? "Option") is released")
            .padding(.horizontal, 30)
            
            Spacer()
            
            HStack {
                styledText(
                    isFocused ?
                    "Press shortcut to open tabs list"
                    :
                    "Shortcut for opening tabs list"
                )
                Spacer()
                KeyboardShortcuts.Recorder(for: .openTabsList) { newShortcut in
                    shortcutModifiers = newShortcut?.modifiers.symbolRepresentation
                }
                    .focused($isFocused)
                    .onChange(of: isFocused) {
                        appState.isShortcutRecorderNeedsToBeFocused = $0
                    }
                    .onChange(of: appState.isShortcutRecorderNeedsToBeFocused) { newValue in
                        Task {
                            isFocused = newValue
                        }
                    }
                    .task {
                        isFocused = appState.isShortcutRecorderNeedsToBeFocused
                    }
            }
            .padding(.horizontal, 30)
        }
        .onChange(of: isTabsSwitcherNeededToStayOpen) { val in
            appState.isTabsSwitcherNeededToStayOpen = val
        }
        .onChange(of: addStatusBarItemWhenAppMovesInBackground) { val in
            if NSApp.activationPolicy() == .regular {
                return
            }
            appState.addStatusBarItemWhenAppMovesInBackground = val
            statusBarItem?.isVisible = val
        }
        .padding(.top, 10)
        .padding(.bottom, 60)
        .frame(minWidth: 444, maxWidth: 444, minHeight: 367, maxHeight: 367)
    }
}
