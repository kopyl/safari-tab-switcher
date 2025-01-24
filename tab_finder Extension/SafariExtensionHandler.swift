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
    var tabsMutated = Store.tabIDsWithTitleAndHost
    let tabIDsWithTitleAndHost = await TabInfoWithID(tabId: tabId, tab: tabs[tabId])
    tabsMutated.append(tabIDsWithTitleAndHost)
    Store.tabIDsWithTitleAndHost = tabsMutated
}

func addAllExistingTabsToHistory(_ tabs: [SFSafariTab], _ tabsFromNavigationHistory: Tabs) async -> Tabs {
    var tabsFromNavigationHistoryMutated = tabsFromNavigationHistory

    var tabsToPrepend: [TabInfoWithID] = []
    for tab in tabs {
        let tabId = tabs.firstIndex(of: tab)
        let tabInfo = await TabInfoWithID(tabId: tabId ?? -1, tab: tab)
        tabsToPrepend.append(tabInfo)
    }
    tabsFromNavigationHistoryMutated.append(contentsOf: tabsToPrepend)

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
    
    let tabInfo = await TabInfoWithID(tabId: changedToTabIndex, tab: activeTab)

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
        let tabInfo = await TabInfoWithID(tabId: historyTab.id, tab: safariTab)
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

    private func postDistributedNotification() {
        let notificationName = Notification.Name("com.tabfinder.example.notification")
        DistributedNotificationCenter.default().postNotificationName(notificationName, object: nil, deliverImmediately: true)
    }

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        guard let command = JScommands(rawValue: messageName) else { return }
        switch command {
        case .opttab:
            Task{
                let tab = await page.containingTab()
                if let window = await tab.containingWindow() {

                    var tabsFromNavigationHistory = Store.tabIDsWithTitleAndHost
                    let tabs = await window.allTabs()
                    
                    tabsFromNavigationHistory = await tabsCleanup(tabs, tabsFromNavigationHistory)
                    
                    Store.tabIDsWithTitleAndHost = tabsFromNavigationHistory
    
                    postDistributedNotification()
                }
            }
        }
    }

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

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task{
            var tabsFromNavigationHistory = Store.tabIDsWithTitleAndHost
            let tabs = await window.allTabs()

            tabsFromNavigationHistory = await addNewTabToHistory(window, tabs, tabsFromNavigationHistory)
            tabsFromNavigationHistory = await tabsCleanup(tabs, tabsFromNavigationHistory)

            Store.tabIDsWithTitleAndHost = tabsFromNavigationHistory
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
