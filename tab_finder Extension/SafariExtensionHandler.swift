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
    addSpecificTabToHistory(tabId: id)
}

func addSpecificTabToHistory(tabId: Int) {
    var tabsMutated = OrderedSet(Store.tabIDs)
    tabsMutated.append(tabId)
    
    Store.currentTabId = tabId
    Store.tabIDs = tabsMutated.elements
}

func addAllExistingTabsToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [Int]) async {
    let tabs = await window.allTabs()
    
    var tabIDsOrderedSet = OrderedSet(tabsFromNavigationHistory)
    tabIDsOrderedSet.append(contentsOf: Array(tabs.indices))
    Store.tabIDs = tabIDsOrderedSet.elements
}

func addNewTabToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [Int]) async {
    var tabsMutated = tabsFromNavigationHistory
    let currentTabId = Store.currentTabId
    
    let tabs = await window.allTabs()
    
    guard let activeTab = await window.activeTab() else { return }
    let changedToTabIndex = tabs.firstIndex(of: activeTab) ?? currentTabId
    if changedToTabIndex == currentTabId {
        return
    }
    Store.currentTabId = changedToTabIndex

    tabsMutated.append(changedToTabIndex)
    Store.tabIDs = tabsMutated
}

func saveAllTabsTitlesToUserDefaults(window: SFSafariWindow) async {
    let titlesAndHostsOfAllTabs = await getTitlesAndHostsOfAllTabs(window: window)
    Store.tabsTitleAndHost = titlesAndHostsOfAllTabs
}

func getTitlesAndHostsOfAllTabs(window: SFSafariWindow) async -> [String: TabInfo] {
    var pageTitlesAndHosts: [String: TabInfo] = [:]
    
    let tabs = await window.allTabs()
    for tab in tabs {
        if let activePage = await tab.activePage() {
            if let properties = await activePage.properties() {
                let key = tabs.firstIndex(of: tab) ?? -1

                let tabInfo = TabInfo(
                    title: properties.title ?? "No title",
                    host: properties.url?.host ?? ""
                )

                pageTitlesAndHosts[String(key)] = tabInfo
                
            }
        }
    }
    
    return pageTitlesAndHosts
}

func removeNonExistentTabsFromHistory(window: SFSafariWindow, tabsFromNavigationHistory: [Int]) async {
    let allTabs = await window.allTabs()
    let currentTabIndices = allTabs.indices

    var tabsMutated = Store.tabIDs
    var tabsTitleAndHost = Store.tabsTitleAndHost

    tabsMutated.removeAll { tabId in
        guard currentTabIndices.contains(tabId) else {
            tabsTitleAndHost.removeValue(forKey: String(tabId))
            return true
        }
        return false
    }

    Store.tabIDs = tabsMutated
    Store.tabsTitleAndHost = tabsTitleAndHost
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
                    let tabsFromNavigationHistory = Store.tabIDs
                    
                    await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    await saveAllTabsTitlesToUserDefaults(window: window)
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
            let tabsFromNavigationHistory = Store.tabIDs
            
            await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            await addNewTabToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            await saveAllTabsTitlesToUserDefaults(window: window)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
