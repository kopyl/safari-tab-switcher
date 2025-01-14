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
}

func switchToTabFromNavigationHistory(by tabIdInNavigaionHistory: Int) async {
    let tabsFromNavigationHistory = Store.allOpenTabsUnique
    
    guard tabsFromNavigationHistory.count > 1 else {
        log("No previous tab to switch to.")
        return
    }

    let previousTabId = tabsFromNavigationHistory.reversed()[tabIdInNavigaionHistory]
    
    await switchToTab(id: previousTabId)
}

func addAllExistingTabsToHistory(window: SFSafariWindow, tabsFromNavigationHistory: [Int]) async {
    let tabs = await window.allTabs()
    
    var allOpenTabsUniqueOrderedSet = OrderedSet(tabsFromNavigationHistory)
    allOpenTabsUniqueOrderedSet.append(contentsOf: Array(tabs.indices))
    Store.allOpenTabsUnique = allOpenTabsUniqueOrderedSet.elements
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
    Store.allOpenTabsUnique = tabsMutated
}

func saveAllTabsTitlesToUserDefaults(window: SFSafariWindow) async {
    let titlesAndHostsOfAllTabs = await getTitlesAndHostsOfAllTabs(window: window)
    Store.allOpenTabsUniqueWithTitlesAndHosts = titlesAndHostsOfAllTabs
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

    var tabsMutated = Store.allOpenTabsUnique
    var allOpenTabsUniqueWithTitlesAndHosts = Store.allOpenTabsUniqueWithTitlesAndHosts

    tabsMutated.removeAll { tabId in
        guard currentTabIndices.contains(tabId) else {
            allOpenTabsUniqueWithTitlesAndHosts.removeValue(forKey: String(tabId))
            return true
        }
        return false
    }

    Store.allOpenTabsUnique = tabsMutated
    Store.allOpenTabsUniqueWithTitlesAndHosts = allOpenTabsUniqueWithTitlesAndHosts
}

enum JScommands: String {
    case opttab
}

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()
}

class SafariExtensionHandler: SFSafariExtensionHandler {
    private var notificationObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        setupDistributedNotificationListener()
    }
    
    deinit {
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            notificationObserver = nil
        }
    }

    private func postDistributedNotification() {
        let notificationName = Notification.Name("com.tabfinder.example.notification")
        DistributedNotificationCenter.default().postNotificationName(notificationName, object: nil, deliverImmediately: true)
    }
    
    private func setupDistributedNotificationListener() {
            let notificationName = Notification.Name("com.tabfinder-toExtension.example.notification")
            
            notificationObserver = DistributedNotificationCenter.default().addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { notification in
                self.handleNotification(notification)
            }
        }

    private func handleNotification(_ notification: Notification) {
        let indexOfTabToSwitchTo = notification.object as? String ?? "-1"
        Task{
            await switchToTabFromNavigationHistory(by: Int(indexOfTabToSwitchTo) ?? -1)
        }
        
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        guard let command = JScommands(rawValue: messageName) else { return }
        switch command {
        case .opttab:
            Task{
                let tab = await page.containingTab()
                if let window = await tab.containingWindow() {
                    let tabsFromNavigationHistory = Store.allOpenTabsUnique
                    
                    await removeNonExistentTabsFromHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    await addAllExistingTabsToHistory(window: window, tabsFromNavigationHistory: tabsFromNavigationHistory)
                    await saveAllTabsTitlesToUserDefaults(window: window)
                }
            }
            postDistributedNotification()
        }
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task{
            let tabsFromNavigationHistory = Store.allOpenTabsUnique
            
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
