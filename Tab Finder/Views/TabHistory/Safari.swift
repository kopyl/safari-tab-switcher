import SafariServices.SFSafariExtensionManager

func hideTabSwitcherUI() {
    NSApp.hide(nil)
    tabsWindow?.orderOut(nil)
}

func openSafari() {
    hideTabSwitcherUI()
    if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
        NSWorkspace.shared.open(safariURL)
    }
}

func openSafariAndAskToSwitchTabs() {
    hideTabSwitcherUI()
    openSafari()
    guard !appState.filteredTabs.isEmpty else { return }
    Task{ await switchTabs() }
}

func switchTabs() async {
    let indexOfTabToSwitchToInSafari = appState.filteredTabs[appState.indexOfTabToSwitchTo]
    do {
        try await SFSafariApplication.dispatchMessage(
            withName: "switchtabto",
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: ["id": String(indexOfTabToSwitchToInSafari.id)]
        )
    } catch let error {
        log("Dispatching message to the extension resulted in an error: \(error)")
    }
}
