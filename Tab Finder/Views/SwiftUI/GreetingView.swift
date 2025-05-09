import SwiftUI

struct OnboardingImage: View {
    var name: String
    
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(height: 458)
    }
}

struct GreetingView: View {
    
    var body: some View {
        VStack {
            HStack(spacing: 33) {
                OnboardingImage(name: AssetNames.Onboarding.left)
                OnboardingImage(name: AssetNames.Onboarding.right)
            }
            .padding(.top, 41)
            Spacer()
            Text(Copy.Onboarding.description)
                .font(.title3)
                .padding(.top, 6)
                .padding(.bottom, 5)
            Spacer()
            
            VStack {
                HStack {
                    StyledButton(.secondary, Copy.Onboarding.configureShortcutButton, icon: "space") {
                        appState.isShortcutRecorderNeedsToBeFocused = true
                        showSettingsWindow()
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    StyledButton(.primary, Copy.Onboarding.hideThisWindowButton, icon: "return") {
                        putIntoBackground()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.bottom, 10)
                Text(Copy.Onboarding.buttonHint)
                    .font(.system(size: 12))
                    .opacity(0.6)
            }
            .padding(.bottom, 41)
            .padding(.horizontal, 41)
        }
    }
}
