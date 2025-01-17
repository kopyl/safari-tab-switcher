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

func switchToTab2(id: Int) async {
    guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
    let allTabs = await activeWindow.allTabs()

    guard allTabs.indices.contains(id) else {
        log("Previous tab ID \(id) is out of range.")
        return
    }
    await allTabs[id].activate()
    await addSpecificTabToHistory2(tabId: id, tab: allTabs[id])
}

func addSpecificTabToHistory(tabId: Int) {
    var tabsMutated = OrderedSet(Store.tabIDs)
    tabsMutated.append(tabId)
    Store.tabIDs = tabsMutated.elements
}

func addSpecificTabToHistory2(tabId: Int, tab: SFSafariTab) async {
    var tabsMutated = Store.tabIDsWithTitleAndHost
    let tabIDsWithTitleAndHost = await TabInfoWithID(tabId: tabId, tab: tab)
    tabsMutated.append(tabIDsWithTitleAndHost)
    Store.tabIDsWithTitleAndHost = tabsMutated
}

func addAllExistingTabsToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [Int]) async {
    let tabs = await window.allTabs()

    var tabIDsOrderedSet = OrderedSet(tabsFromNavigationHistory)
    tabIDsOrderedSet.append(contentsOf: Array(tabs.indices))
    Store.tabIDs = tabIDsOrderedSet.elements
}

func addAllExistingTabsToHistory2(window: SFSafariWindow, tabsFromNavigationHistory: OrderedSet2<TabInfoWithID>) async -> OrderedSet2<TabInfoWithID> {
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

func addNewTabToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [Int]) async {
    var tabsMutated = tabsFromNavigationHistory
    let tabs = await window.allTabs()

    guard let activeTab = await window.activeTab() else { return }
    guard let changedToTabIndex = tabs.firstIndex(of: activeTab) else { return }

    tabsMutated.append(changedToTabIndex)
    Store.tabIDs = tabsMutated
    
}

func addNewTabToHistory2(window: SFSafariWindow, tabsFromNavigationHistory: OrderedSet2<TabInfoWithID>) async -> OrderedSet2<TabInfoWithID> {
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
    log("removeNonExistentTabsFromHistory after filter: \(tabsMutated)")
}

func removeNonExistentTabsFromHistory2(window: SFSafariWindow, tabsFromNavigationHistory: OrderedSet2<TabInfoWithID>) async {
    let allTabs = await window.allTabs()
    let currentTabIndices = allTabs.indices
    
    Store.tabIDsWithTitleAndHost = tabsFromNavigationHistory.filter { tab in
        currentTabIndices.contains(tab.id)
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
                    let tabsFromNavigationHistory = Store.tabIDs
                    var tabsFromNavigationHistory2 = Store.tabIDsWithTitleAndHost

                    await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    tabsFromNavigationHistory2 = await addAllExistingTabsToHistory2(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)

                    await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    await removeNonExistentTabsFromHistory2(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
                    
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
            var tabsFromNavigationHistory2 = Store.tabIDsWithTitleAndHost

            await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            tabsFromNavigationHistory2 = await addAllExistingTabsToHistory2(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
            
            await addNewTabToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            tabsFromNavigationHistory2 = await addNewTabToHistory2(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
            
            await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
            await removeNonExistentTabsFromHistory2(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory2)
//
            await saveAllTabsTitlesToUserDefaults(window: window)
            
            log("Store.tabIDs after updates: \(Store.tabIDs)")
            log("Store.tabIDsWithTitleAndHost after updates: \(Store.tabIDsWithTitleAndHost.elements.map{$0.id})")
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
