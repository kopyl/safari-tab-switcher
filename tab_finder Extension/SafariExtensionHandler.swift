import SafariServices
import SwiftUI

func switchToTab(id: Int) async {
    guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
    let allTabs = await activeWindow.allTabs()

    guard allTabs.indices.contains(id) else {
        log("Previous tab ID \(id) is out of range.")
        return
    }
    await allTabs[id].activate()
    await addSpecificTabToHistory(tabId: id, tab: allTabs[id])
}

func addSpecificTabToHistory(tabId: Int, tab: SFSafariTab) async {
    var tabsMutated = Store.tabIDsWithTitleAndHost
    let tabIDsWithTitleAndHost = await TabInfoWithID(tabId: tabId, tab: tab)
    tabsMutated.append(tabIDsWithTitleAndHost)
    Store.tabIDsWithTitleAndHost = tabsMutated
}

func addAllExistingTabsToHistory(window: SFSafariWindow, tabsFromNavigationHistory: OrderedSet2<TabInfoWithID>) async -> OrderedSet2<TabInfoWithID> {
    let tabs = await window.allTabs()
    
    var tabsFromNavigationHistoryMutated = tabsFromNavigationHistory

    var tabsToPrepend: [TabInfoWithID] = []
    for tab in tabs {
        let tabId = tabs.firstIndex(of: tab)
        let tabInfo = await TabInfoWithID(tabId: tabId ?? -1, tab: tab)
        tabsToPrepend.append(tabInfo)
    }
    tabsFromNavigationHistoryMutated.append(contentsOf: tabsToPrepend)

    Store.tabIDsWithTitleAndHost = tabsFromNavigationHistoryMutated
    return tabsFromNavigationHistoryMutated
}

func addNewTabToHistory(window: SFSafariWindow, tabsFromNavigationHistory: OrderedSet2<TabInfoWithID>) async -> OrderedSet2<TabInfoWithID> {
    var tabsMutated = tabsFromNavigationHistory

    let tabs = await window.allTabs()

    guard let activeTab = await window.activeTab() else {
        return tabsMutated
    }
    guard let changedToTabIndex = tabs.firstIndex(of: activeTab) else {
        return tabsMutated
    }
    
    let tabInfo = await TabInfoWithID(tabId: changedToTabIndex, tab: activeTab)

    tabsMutated.append(tabInfo)
    Store.tabIDsWithTitleAndHost = tabsMutated
    return tabsMutated
}

func removeNonExistentTabsFromHistory(window: SFSafariWindow, tabsFromNavigationHistory: OrderedSet2<TabInfoWithID>) async {
    let allTabs = await window.allTabs()
    
    Store.tabIDsWithTitleAndHost = tabsFromNavigationHistory.filter { tab in
        allTabs.indices.contains(tab.id)
    }
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

                    var tabsFromNavigationHistory2 = Store.tabIDsWithTitleAndHost

                    tabsFromNavigationHistory2 = await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)

                    await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
                }
            }
            postDistributedNotification()
        }
    }

    override func messageReceivedFromContainingApp(withName: String, userInfo: [String : Any]?) {
        guard let command = AppCommands(rawValue: withName) else { return }
        switch command {
        case .switchtabto:
            guard let tabIdString = userInfo?["id"] as? String,
                  let tabId = Int(tabIdString) else { return }
            Task{
                await switchToTab(id: tabId)
            }
        }
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task{
            var tabsFromNavigationHistory2 = Store.tabIDsWithTitleAndHost

            tabsFromNavigationHistory2 = await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
            tabsFromNavigationHistory2 = await addNewTabToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
            
            await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
