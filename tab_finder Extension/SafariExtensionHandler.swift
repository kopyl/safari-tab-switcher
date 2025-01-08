import SafariServices
import os.log
import SwiftUI
import UserNotifications

struct HelloWorldView: View {
    @State private var tabCount: Int = 0

    var body: some View {
        VStack {
            Text("You have \(tabCount) open tabs")
                .font(.largeTitle)
                .padding()
            Button("Close") {
                SafariExtensionViewController.shared.dismissPopover()
            }
            .padding()
            .onAppear{
                getOpenTabsCount { count in
                    tabCount = count
                }
            }
        }
    }
}

func getOpenTabsCount(completion: @escaping (Int) -> Void) {
    SFSafariApplication.getAllWindows { windows in
        var totalTabs = 0
        let group = DispatchGroup()

        for window in windows {
            group.enter()
            window.getAllTabs { tabs in
                totalTabs += tabs.count
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(totalTabs)
        }
    }
}

func showPopover() {
    SFSafariApplication.getActiveWindow { (window) in
        window?.getToolbarItem(completionHandler: { (item) in
            item?.showPopover()
        })
    }
}

func switchToTab(id: Int) {
    SFSafariApplication.getActiveWindow { activeWindow in
        activeWindow?.getAllTabs { tabs in
            guard tabs.indices.contains(id) else {
                FileLogger.shared.log("Previous tab ID \(id) is out of range.")
                return
            }
            tabs[id].activate {
                FileLogger.shared.log("Switching to a tab")
            }
        }
    }
}

func getTitlesOfAllTabs(_ tabs: [SFSafariTab]) async -> [String: String] {
    var pageTitles: [String: String] = [:]
    for tab in tabs {
        guard let activePage = await tab.activePage() else { return pageTitles }
        guard let properties = await activePage.properties() else { return pageTitles }
        guard let title = properties.title else { return pageTitles }
        let key = tabs.firstIndex(of: tab) ?? -1
        pageTitles[String(key)] = title
    }
    FileLogger.shared.log("pageTitles: \(pageTitles)")
    return pageTitles
}

func getTitlesOfAllTabs(window: SFSafariWindow) async -> [String: String] {
    var pageTitles: [String: String] = [:]
    let tabs = await window.allTabs()
    for tab in tabs {
        guard let activePage = await tab.activePage() else { return pageTitles }
        guard let properties = await activePage.properties() else { return pageTitles }
        guard let title = properties.title else { return pageTitles }
        let key = tabs.firstIndex(of: tab) ?? -1
        pageTitles[String(key)] = title
    }
    FileLogger.shared.log("pageTitles: \(pageTitles)")
    return pageTitles
}

func saveAllTabsTitlesToUserDefaults(window: SFSafariWindow) async -> Int {
    let titleOfAllTabs = await getTitlesOfAllTabs(window: window)
    UserDefaults.standard.set(titleOfAllTabs, forKey: "allOpenTabsUniqueWithTitles")
    return 1
}

func getTitleOfOneTab(tab: SFSafariTab) async -> String {
    guard let activePage = await tab.activePage() else { return "" }
    guard let properties = await activePage.properties() else { return "" }
    guard let title = properties.title else { return "" }
    return title
}

func getOpenTabs() -> OrderedSet<Int> {
    return OrderedSet(UserDefaults.standard.array(forKey: "allOpenTabsUnique") as? [Int] ?? [])
}

func addNewTabToHistory(window: SFSafariWindow) async -> Int {
    var allOpenTabsUnique = getOpenTabs()
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    
    let tabs = await window.allTabs()
    guard let activeTab = await window.activeTab() else { return 0 }
    let changedToTabIndex = tabs.firstIndex(of: activeTab) ?? currentTabId
    if changedToTabIndex == currentTabId {
        return 0
    }
    UserDefaults.standard.set(changedToTabIndex, forKey: "currentTabId")

    allOpenTabsUnique.append(changedToTabIndex)
    UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
    
    FileLogger.shared.log("\(allOpenTabsUnique.elements)")
    
    return 1
}

func removeTabFromHistory() {
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    var allOpenTabsUnique = getOpenTabs()
    allOpenTabsUnique.remove(currentTabId)
    UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
    FileLogger.shared.log("Tab \(currentTabId) removed from history")
}

func switchToPreviousTab() {
    let allOpenTabsUnique = getOpenTabs()
    
    guard allOpenTabsUnique.count > 1 else {
            FileLogger.shared.log("No previous tab to switch to.")
            return
        }

    let previousTabId = allOpenTabsUnique[-2]
    FileLogger.shared.log("Switching to previous tab ID: \(previousTabId)")
    
    switchToTab(id: previousTabId)
}

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        FileLogger.shared.log("Command received: \(messageName)")
        if messageName == "opttab" {
            switchToPreviousTab()
        } else if messageName == "tabclose" {
            FileLogger.shared.log("Command for closing tab is received")
            removeTabFromHistory()
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {}

override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
    Task {
        async let saveTab = addNewTabToHistory(window: window)
        async let saveTabs = saveAllTabsTitlesToUserDefaults(window: window)
        let _ = await (saveTab, saveTabs)
    }
    validationHandler(true, "")
}

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
