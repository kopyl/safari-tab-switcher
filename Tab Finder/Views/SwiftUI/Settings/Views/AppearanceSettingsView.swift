import SwiftUI
import SafariServices.SFSafariExtensionManager

func changeTransparencyOfExtensionIconInSafariToolbar(shouldBeTransparent: Bool) {
    Task {
        do {
            try await SFSafariApplication.dispatchMessage(
                withName: "changetoolbaricontransparency",
                toExtensionWithIdentifier: extensionBundleIdentifier,
                userInfo: ["shouldBeTransparent": shouldBeTransparent ? "1" : "0"]
            )
        } catch {}
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
        HStack(spacing: 0) {
            ForEach(colors, id: \.self) { color in
                Button(action: {
                    userSelectedAccentColor = colorToHex(color)
                }) {
                    ZStack {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .frame(width: 52, height: 52)
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
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(
        Store.sortTabsByStoreKey,
        store: Store.userDefaults
    ) private var sortTabsBy: SortTabsBy = Store.sortTabsByDefaultValue
    
    @AppStorage(
        Store.columnOrderStoreKey,
        store: Store.userDefaults
    ) private var columnOrder: ColumnOrder = Store.columnOrderDefaultValue
    
    @AppStorage(
        Store.userSelectedAccentColorStoreKey,
        store: Store.userDefaults
    ) private var userSelectedAccentColor: String = Store.userSelectedAccentColorDefaultValue
    
    @AppStorage(
        Store.addStatusBarItemWhenAppMovesInBackgroundStoreKey,
        store: Store.userDefaults
    ) private var addStatusBarItemWhenAppMovesInBackground: Bool = Store.addStatusBarItemWhenAppMovesInBackgroundDefaultValue
    
    @AppStorage(
        Store.shallSafariIconBeTransparentStoreKey,
        store: Store.userDefaults
    ) private var shallSafariIconBeTransparent: Bool = Store.shallSafariIconBeTransparentDefaultValue
    
    @State private var displayedColorName: String = ""
    
    @ObservedObject var appState: AppState

    var colorName: String {
        colorNames[colors.firstIndex(of: hexToColor(userSelectedAccentColor)) ?? 0]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 46) {
            
            HStack {
                styledText("Sort tabs by")
                Spacer()
                Picker("", selection: $sortTabsBy) {
                    ForEach(SortTabsBy.allCases, id: \.self) { item in
                        Text(item.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 250)
            }
            .padding(.horizontal, 30)
            
            HStack {
                styledText("Column order")
                Spacer()
                Picker("", selection: $columnOrder) {
                    ForEach(ColumnOrder.allCases, id: \.self) { item in
                        Text(item.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 250)
            }
            .padding(.horizontal, 30)
            
            VStack(alignment: .leading, spacing: 20) {  
                ToggleView(isOn: $addStatusBarItemWhenAppMovesInBackground, text: "Show menu bar icon when app hides in background")
                ToggleView(isOn: $shallSafariIconBeTransparent, text: "Make Safari toolbar icon transparent")
            }
            .padding(.horizontal, 30)
            
            VStack(spacing: 12) {
                HStack {
                    styledText("Accent color")
                    Spacer()
                    Text(displayedColorName)
                        .opacity(0.6)
                        .id(displayedColorName)
                        .font(.system(size: 11))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .clipped()
                }
                .padding(.horizontal, 30)
                ColorPickerView()
            }
        }
        .onAppear {
            displayedColorName = colorName
        }
        .onChange(of: userSelectedAccentColor) { _ in
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 13)) {
                displayedColorName = colorName
            }
        }
        .onChange(of: sortTabsBy) { val in
            appState.sortTabsBy = val
        }
        .onChange(of: columnOrder) { val in
            appState.columnOrder = val
        }
        .onChange(of: userSelectedAccentColor) { val in
            appState.userSelectedAccentColor = val
        }
        .onChange(of: addStatusBarItemWhenAppMovesInBackground) { val in
            if NSApp.activationPolicy() == .regular {
                return
            }
            appState.addStatusBarItemWhenAppMovesInBackground = val
            statusBarItem?.isVisible = val
        }
        .onChange(of: shallSafariIconBeTransparent) { val in
            changeTransparencyOfExtensionIconInSafariToolbar(shouldBeTransparent: val)
        }
        .padding(.top, 10)
        .padding(.bottom, 42)
        .frame(minWidth: 444, maxWidth: 444)
    }
}
