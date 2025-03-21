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

let colors: [Color] = [
    Color(red: 25/255, green: 25/255, blue: 25/255),
    Color(red: 0/255, green: 122/255, blue: 255/255),
    Color(red: 166/255, green: 79/255, blue: 167/255),
    Color(red: 247/255, green: 79/255, blue: 158/255),
    Color(red: 255/255, green: 83/255, blue: 87/255),
    Color(red: 246/255, green: 129/255, blue: 28/255),
    Color(red: 255/255, green: 198/255, blue: 0/255),
    Color(red: 99/255, green: 186/255, blue: 71/255)
]

let colorNames = [
    "Darkened",
    "Blue",
    "Purple",
    "Pink",
    "Red",
    "Orange",
    "Yellow",
    "Green"
]

func hexToColor(_ hex: String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if hexSanitized.hasPrefix("#") {
        hexSanitized.remove(at: hexSanitized.startIndex)
    }
    
    var rgbValue: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
    
    let red = Double((rgbValue >> 16) & 0xFF) / 255.0
    let green = Double((rgbValue >> 8) & 0xFF) / 255.0
    let blue = Double(rgbValue & 0xFF) / 255.0
    
    return Color(red: red, green: green, blue: blue)
}

struct ColorPickerView: View {
    @AppStorage(
        Store.userSelectedAccentColorStoreKey,
        store: Store.userDefaults
    ) private var userSelectedAccentColor: String = Store.userSelectedAccentColorDefaultValue
    
    private func colorToHex(_ color: Color) -> String {
        if let uiColor = NSColor(color).cgColor.components {
            let r = Int((uiColor[0] * 255).rounded())
            let g = Int((uiColor[1] * 255).rounded())
            let b = Int((uiColor[2] * 255).rounded())
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return "#000000"
    }
    
    var body: some View {
        HStack(spacing: 36) {
            ForEach(colors, id: \.self) { color in
                Button(action: {
                    userSelectedAccentColor = colorToHex(color)
                }) {
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)

                        )
                        .overlay(
                            Circle()
                                .fill(.white)
                                .scaleEffect(userSelectedAccentColor == colorToHex(color) ? 0.33 : 0)
                                .animation(.linear(duration: 0.1), value: userSelectedAccentColor)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}


struct SettingsView: View {
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = false
    
    @AppStorage(
        Store.userSelectedAccentColorStoreKey,
        store: Store.userDefaults
    ) private var userSelectedAccentColor: String = Store.userSelectedAccentColorDefaultValue
    
    @State private var displayedColorName: String = ""
    
    @State
    var shortcutModifiers =
    KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers.symbolRepresentation
    
    @ObservedObject var appState: AppState
    @FocusState private var isFocused: Bool

    var colorName: String {
        colorNames[colors.firstIndex(of: hexToColor(userSelectedAccentColor)) ?? 0]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 86) {
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
                    "Press shortcut to open tabs list"
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
                        Task {
                            isFocused = newValue
                        }
                    }
                    .task {
                        isFocused = appState.isShortcutRecorderNeedsToBeFocused
                    }
            }
            
            VStack(spacing: 30) {
                HStack {
                    Text("Accent color")
                        .font(.system(size: 15))
                    Spacer()
                    Text(displayedColorName)
                        .id(displayedColorName)
                        .font(.system(size: 11))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .clipped()
                }
                ColorPickerView()
            }
        }
        .onAppear {
            displayedColorName = colorName
        }
        .onChange(of: userSelectedAccentColor) { _ in
            withAnimation(.linear(duration: 0.2)) {
                displayedColorName = colorName
            }
        }
        .padding(.top, 74)
        .padding(.bottom, 89)
        .padding(.horizontal, 30)
    }
}
