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
    var tabsMutated = OrderedSet(Store.tabIDsWithTitleAndHost)
    let tabIDsWithTitleAndHost = await TabInfoWithID(tabId: tabId, tab: tab)
    tabsMutated.append(tabIDsWithTitleAndHost)

    Store.currentTabId = tabId
    Store.tabIDsWithTitleAndHost = tabsMutated.elements
    log("addSpecificTabToHistory: \(tab)")
}

func addAllExistingTabsToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [TabInfoWithID]) async {
    let tabs = await window.allTabs()
    
    var tabsFromNavigationHistoryOrderedSet = OrderedSet(tabsFromNavigationHistory)

    var tabsToPrepend: [TabInfoWithID] = []
    for tab in tabs {
        let tabId = tabs.firstIndex(of: tab)
        let tabInfo = await TabInfoWithID(tabId: tabId ?? -1, tab: tab)
        tabsToPrepend.append(tabInfo)
    }
    tabsFromNavigationHistoryOrderedSet.append(contentsOf: tabsToPrepend)

    Store.tabIDsWithTitleAndHost = tabsFromNavigationHistoryOrderedSet.elements
}

func addNewTabToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [TabInfoWithID]) async {
    var tabsMutated = tabsFromNavigationHistory
    let currentTabId = Store.currentTabId

    let tabs = await window.allTabs()

    guard let activeTab = await window.activeTab() else { return }
    let changedToTabIndex = tabs.firstIndex(of: activeTab) ?? currentTabId
    if changedToTabIndex == currentTabId {
        return
    }
    Store.currentTabId = changedToTabIndex
    
    let tabInfo = await TabInfoWithID(tabId: changedToTabIndex, tab: activeTab)

    tabsMutated.append(tabInfo)
    log(tabInfo)
    Store.tabIDsWithTitleAndHost = tabsMutated
}


func removeNonExistentTabsFromHistory(window: SFSafariWindow, tabsFromNavigationHistory: [TabInfoWithID]) async {
    let allTabs = await window.allTabs()
    let currentTabIndices = allTabs.indices

    var tabsMutated = tabsFromNavigationHistory
    
    tabsMutated.removeAll { tab in
            guard currentTabIndices.contains(tab.id) else { return true }
            return false
        }

    Store.tabIDsWithTitleAndHost = tabsMutated
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
                    let tabsFromNavigationHistory = Store.tabIDsWithTitleAndHost

                    await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
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
            let tabsFromNavigationHistory = Store.tabIDsWithTitleAndHost

            await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            await addNewTabToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
