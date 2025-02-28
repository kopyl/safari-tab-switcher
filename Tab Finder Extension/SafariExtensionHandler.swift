import SafariServices
import SwiftUI

func switchToTab(id: Int, tabs: [SFSafariTab]) async {
    guard tabs.indices.contains(id) else {
        log("Previous tab ID \(id) is out of range.")
        return
    }
    await tabs[id].activate()
    await addSpecificTabToHistory(tabId: id, tabs: tabs)
}

func addSpecificTabToHistory(tabId: Int, tabs: [SFSafariTab]) async {
    var windows = Store.windows
    guard var tabsMutated = windows.windows.last?.tabs else { return }
    
    let tabIDsWithTitleAndHost = await Tab(id: tabId, tab: tabs[tabId])
    tabsMutated.append(tabIDsWithTitleAndHost)
    
    let currentWindow = _Window(tabs: tabsMutated)
    windows.append(currentWindow)
    
    Store.windows = windows
}

func addAllExistingTabsToHistory(_ tabs: [SFSafariTab], _ tabsFromNavigationHistory: Tabs) async -> Tabs {
    var tabsFromNavigationHistoryMutated = tabsFromNavigationHistory

    var tabsToPrepend: [Tab] = []
    for tab in tabs {
        let tabId = tabs.firstIndex(of: tab)
        let tabInfo = await Tab(id: tabId ?? -1, tab: tab)
        tabsToPrepend.append(tabInfo)
    }
    tabsFromNavigationHistoryMutated.prepend(contentsOf: tabsToPrepend)

    return tabsFromNavigationHistoryMutated
}

func addNewTabToHistory(_ window: SFSafariWindow, _ tabs: [SFSafariTab], _ tabsFromNavigationHistory: Tabs) async -> Tabs {
    var tabsMutated = tabsFromNavigationHistory

    guard let activeTab = await window.activeTab() else {
        return tabsMutated
    }
    guard let changedToTabIndex = tabs.firstIndex(of: activeTab) else {
        return tabsMutated
    }
    
    let tabInfo = await Tab(id: changedToTabIndex, tab: activeTab)

    tabsMutated.append(tabInfo)

    return tabsMutated
}

func removeNonExistentTabsFromHistory(_ tabs: [SFSafariTab], _ tabsFromNavigationHistory: Tabs) async -> Tabs {
    return tabsFromNavigationHistory.filter { tab in
        tabs.indices.contains(tab.id)
    }
}

func makeSureEveryOtherTabInfoIsCorrect(_ tabs: [SFSafariTab], _ tabsFromNavigationHistory: Tabs) async -> Tabs {
    var allTabsInfoUpdated = Tabs()
    
    for historyTab in tabsFromNavigationHistory {
        let safariTab = tabs[historyTab.id]
        let tabInfo = await Tab(id: historyTab.id, tab: safariTab)
        allTabsInfoUpdated.append(tabInfo)
    }
    
    return allTabsInfoUpdated
}

func tabsCleanup(_ tabs: [SFSafariTab], _ tabsFromNavigationHistory: Tabs) async -> Tabs {
    var tabsHistoryMutated = tabsFromNavigationHistory
    tabsHistoryMutated = await addAllExistingTabsToHistory(tabs, tabsHistoryMutated)
    tabsHistoryMutated = await removeNonExistentTabsFromHistory(tabs, tabsHistoryMutated)
    tabsHistoryMutated = await makeSureEveryOtherTabInfoIsCorrect(tabs, tabsHistoryMutated)
    return tabsHistoryMutated
}

func saveWindows(tabs: Tabs) async {
    var windows = Store.windows
    let currentWindow = _Window(tabs: tabs)

    windows.append(currentWindow)

    let allWindows = await SFSafariApplication.allWindows()
    var newWindowCombinedIDs: [String] = []
    for window in allWindows {
        newWindowCombinedIDs.append(await window.id())
    }
    
    windows = windows.filter{ window in
        newWindowCombinedIDs.contains(window.combinedID)
    }
    
    Store.windows = windows
}

enum JScommands: String {
    case opttab
}

enum AppCommands: String {
    case switchtabto
}

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()
}

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func messageReceivedFromContainingApp(withName: String, userInfo: [String : Any]?) {
        guard let command = AppCommands(rawValue: withName) else { return }
        switch command {
        case .switchtabto:
            guard let tabIdString = userInfo?["id"] as? String,
                  let tabId = Int(tabIdString) else { return }
            Task{
                guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
                let tabs = await activeWindow.allTabs()
                await switchToTab(id: tabId, tabs: tabs)
            }
        }
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        let url = URL(string: "tabfinder://")!
        NSWorkspace.shared.open(url)
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task{
            var tabsFromNavigationHistory =
                await Store.windows.get(SFWindow: window)?.tabs
                ?? Store.windows.windows.last?.tabs
                ?? _Window(tabs: Tabs()).tabs
            
            let tabs = await window.allTabs()

            tabsFromNavigationHistory = await addNewTabToHistory(window, tabs, tabsFromNavigationHistory)
            tabsFromNavigationHistory = await tabsCleanup(tabs, tabsFromNavigationHistory)
            
            await saveWindows(tabs: tabsFromNavigationHistory)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
