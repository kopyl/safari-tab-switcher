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
    log("Switching to a tab")
}

func switchToPreviousTab(by idx: Int) async {
    let allOpenTabsUnique = getOpenTabs()
    
    guard allOpenTabsUnique.count > 1 else {
            log("No previous tab to switch to.")
            return
        }

    let previousTabId = allOpenTabsUnique.reversed()[idx]
    log("Switching to previous tab ID: \(previousTabId)")
    
    await switchToTab(id: previousTabId)
}

func getOpenTabs() -> [Int] {
    let openTabs = Store.allOpenTabsUnique
    return openTabs
}

func addNewTabToHistory(window: SFSafariWindow) async {
    var allOpenTabsUnique = getOpenTabs()
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    
    let tabs = await window.allTabs()
    guard let activeTab = await window.activeTab() else { return }
    let changedToTabIndex = tabs.firstIndex(of: activeTab) ?? currentTabId
    if changedToTabIndex == currentTabId {
        return
    }
    Store.currentTabId = changedToTabIndex

    allOpenTabsUnique.append(changedToTabIndex)
    Store.allOpenTabsUnique = allOpenTabsUnique
}

func saveAllTabsTitlesToUserDefaults(window: SFSafariWindow) async {
    let titleOfAllTabs = await getTitlesAndHostsOfAllTabs(window: window)
    Store.allOpenTabsUniqueWithTitles = titleOfAllTabs
}

func getTitlesAndHostsOfAllTabs(window: SFSafariWindow) async -> [String: String] {
    var pageTitles: [String: String] = [:]
    var pageHosts: [String: String] = [:]
    
    let tabs = await window.allTabs()
    for tab in tabs {
        if let activePage = await tab.activePage() {
            if let properties = await activePage.properties() {
                let key = tabs.firstIndex(of: tab) ?? -1
                
                if let title = properties.title {
                    pageTitles[String(key)] = title
                }
                if let host = properties.url?.host {
                    pageHosts[String(key)] = host
                }
            }
        }
    }
    
    return pageTitles
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
        let allOpenTabsUnique = getOpenTabs()
	
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
        Task{
            let indexOfTabToSwitchTo = notification.object as? String ?? "-1"
            log("\(indexOfTabToSwitchTo) indexOfTabToSwitchTo")
            await switchToPreviousTab(by: Int(indexOfTabToSwitchTo) ?? -1)
        }
        
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        guard let command = JScommands(rawValue: messageName) else { return }
        switch command {
        case .opttab:
            postDistributedNotification()
        }
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task{
            await saveAllTabsTitlesToUserDefaults(window: window)
            await addNewTabToHistory(window: window)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
