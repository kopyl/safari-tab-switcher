import SafariServices
import SwiftUI

struct HelloWorldView: View {
    @State private var tabCount: Int = 0
    @State private var tabTitles: [String: String] = [:]
    @State private var allOpenTabsUnique: [Int] = []

    var body: some View {
        VStack {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    let tabsToDisplay = Array(allOpenTabsUnique.reversed())
                    
                    ForEach(tabsToDisplay.indices, id: \.self) { tabIdx in
                        Text(tabTitles[String(tabsToDisplay[tabIdx])] ?? "No title")
                            .font(.system(size: 15))
                            .lineLimit(1)
                            .padding(.top, 10).padding(.bottom, tabIdx != tabsToDisplay.indices.last ? 10 : 20)
                            .padding(.leading, 10).padding(.trailing, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.blue.opacity(tabIdx == 0 ? 1 : 0))
                        
                        if tabIdx != tabsToDisplay.indices.last && tabIdx != tabsToDisplay.indices.first {
                            Divider().background(.gray.opacity(0.01))
                        }
                    }
                }
            }
            .frame(width: 300, height: 200)
            .task{
                let savedTabTitles = UserDefaults.standard.dictionary(forKey: "allOpenTabsUniqueWithTitles") as? [String : String]
                tabTitles = savedTabTitles ?? [:]
                allOpenTabsUnique = getOpenTabs().elements

            }
        }
    }
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
        log("Previous tab ID \(id) is out of range.")
        return
    }
    await allTabs[id].activate()
    log("Switching to a tab")
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

func saveAllTabsTitlesToUserDefaults(window: SFSafariWindow) async {
    let titleOfAllTabs = await getTitlesAndHostsOfAllTabs(window: window)
    UserDefaults.standard.set(titleOfAllTabs, forKey: "allOpenTabsUniqueWithTitles")
    log("allOpenTabsUniqueWithTitles saved")
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
    
    log("addNewTabToHistory saved \(allOpenTabsUnique.elements)")
}

func removeTabFromHistory() {
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    var allOpenTabsUnique = getOpenTabs()
    allOpenTabsUnique.remove(currentTabId)
    UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
    log("Tab \(currentTabId) removed from history")
}

func switchToPreviousTab() async {
    let allOpenTabsUnique = getOpenTabs()
    
    guard allOpenTabsUnique.count > 1 else {
            log("No previous tab to switch to.")
            return
        }

    let previousTabId = allOpenTabsUnique[-2]
    log("Switching to previous tab ID: \(previousTabId)")
    
    await switchToTab(id: previousTabId)
}

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        log("Command received: \(messageName)")
        if messageName == "opttab" {
            Task {
                await switchToPreviousTab()
            }
        } else if messageName == "tabclose" {
            log("Command for closing tab is received")
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
