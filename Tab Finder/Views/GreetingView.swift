import SwiftUI

func startUsingTabFinder() {
    greetingWindow?.orderOut(nil)
    settingsWindow?.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
}

struct OnboardingImage: View {
    var name: String
    
    var body: some View {
        if let onboardingImageLeft = NSImage(named: name) {
            Image(nsImage: onboardingImageLeft)
                .resizable()
                .scaledToFit()
                .frame(height: 458)
        }
    }
}

struct GreetingView: View {
    @ObservedObject var appState: AppState
    
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
                OnboardingButton {
                    startUsingTabFinder()
                    appState.isUserOnboarded = true
                }
                .padding(.bottom, 10)
                Text(Copy.Onboarding.buttonHint)
                    .font(.system(size: 12))
                    .opacity(0.6)
            }
            .padding(.bottom, 41)
            .padding(.horizontal, 41)
        }
        .onDisappear {
            startUsingTabFinder()
            appState.isUserOnboarded = true
        }
    }
}
