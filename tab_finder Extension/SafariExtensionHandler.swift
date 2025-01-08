import SafariServices
import SwiftUI

struct HelloWorldView: View {
    @State private var tabCount: Int = 0
    @State private var tabTitles: [String: String] = [:]
    @State private var allOpenTabsUnique: [Int] = []

    var body: some View {
        VStack {
            Text("You have \(tabCount) open tabs")
                .font(.largeTitle)
                .padding()
            VStack {
                ForEach(allOpenTabsUnique, id: \.self) { tab in
                    
                    Text(tabTitles[String(tab)] ?? "No title")
                }
            }
            Button("Close") {
                SafariExtensionViewController.shared.dismissPopover()
            }
            .padding()
            .task{
                tabCount = await getOpenTabsCount()
  
                let savedTabTitles = UserDefaults.standard.dictionary(forKey: "allOpenTabsUniqueWithTitles") as? [String : String]
                tabTitles = savedTabTitles ?? [:]
                
                allOpenTabsUnique = getOpenTabs().elements

            }
        }
    }
}

func getOpenTabsCount() async -> Int {
    var totalTabs = 0
    let allWindows = await SFSafariApplication.allWindows()
    for window in allWindows {
        let allTabs = await window.allTabs()
        totalTabs += allTabs.count
    }
    return totalTabs
}

func showPopover() async {
    guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
    guard let toolbarItem = await activeWindow.toolbarItem() else { return }
    toolbarItem.showPopover()
}

func switchToTab(id: Int) async {
    guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
    let allTabs = await activeWindow.allTabs()
    
    guard allTabs.indices.contains(id) else {
        FileLogger.shared.log("Previous tab ID \(id) is out of range.")
        return
    }
    await allTabs[id].activate()
    FileLogger.shared.log("Switching to a tab")
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
    return pageTitles
}

func getTitlesOfAllTabs(window: SFSafariWindow) async -> [String: String] {
    var pageTitles: [String: String] = [:]
    let tabs = await window.allTabs()
    for tab in tabs {
        if let activePage = await tab.activePage() {
            if let properties = await activePage.properties() {
                if let title = properties.title {
                    let key = tabs.firstIndex(of: tab) ?? -1
                    pageTitles[String(key)] = title
                }
            }
        }
    }
    return pageTitles
}

func saveAllTabsTitlesToUserDefaults(window: SFSafariWindow) async {
    let titleOfAllTabs = await getTitlesOfAllTabs(window: window)
    UserDefaults.standard.set(titleOfAllTabs, forKey: "allOpenTabsUniqueWithTitles")
    FileLogger.shared.log("allOpenTabsUniqueWithTitles saved")
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

func addNewTabToHistory(window: SFSafariWindow) async {
    var allOpenTabsUnique = getOpenTabs()
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    
    let tabs = await window.allTabs()
    guard let activeTab = await window.activeTab() else { return }
    let changedToTabIndex = tabs.firstIndex(of: activeTab) ?? currentTabId
    if changedToTabIndex == currentTabId {
        return
    }
    UserDefaults.standard.set(changedToTabIndex, forKey: "currentTabId")

    allOpenTabsUnique.append(changedToTabIndex)
    UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
    
    FileLogger.shared.log("addNewTabToHistory saved \(allOpenTabsUnique.elements)")
}

func removeTabFromHistory() {
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    var allOpenTabsUnique = getOpenTabs()
    allOpenTabsUnique.remove(currentTabId)
    UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
    FileLogger.shared.log("Tab \(currentTabId) removed from history")
}

func switchToPreviousTab() async {
    let allOpenTabsUnique = getOpenTabs()
    
    guard allOpenTabsUnique.count > 1 else {
            FileLogger.shared.log("No previous tab to switch to.")
            return
        }

    let previousTabId = allOpenTabsUnique[-2]
    FileLogger.shared.log("Switching to previous tab ID: \(previousTabId)")
    
    await switchToTab(id: previousTabId)
}

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        FileLogger.shared.log("Command received: \(messageName)")
        if messageName == "opttab" {
            Task {
                await switchToPreviousTab()
            }
        } else if messageName == "tabclose" {
            FileLogger.shared.log("Command for closing tab is received")
            removeTabFromHistory()
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {}

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task {
            async let _ = addNewTabToHistory(window: window)
            async let _ = saveAllTabsTitlesToUserDefaults(window: window)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
