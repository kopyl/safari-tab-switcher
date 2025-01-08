import SafariServices
import os.log
import SwiftUI
import UserNotifications

@available(macOS 12.0, *)
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

@available(macOSApplicationExtension 12.0, *)
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

func getOpenTabs() -> OrderedSet<Int> {
    return OrderedSet(UserDefaults.standard.array(forKey: "allOpenTabsUnique") as? [Int] ?? [])
}

@available(macOSApplicationExtension 12.0, *)
func addNewTabToHistory(window: SFSafariWindow) {
    var allOpenTabsUnique = getOpenTabs()
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    window.getAllTabs { tabs in
        window.getActiveTab { tab in
            if let tab {
                let changedToTabIndex = tabs.firstIndex(of: tab) ?? currentTabId
                if changedToTabIndex == currentTabId {
                    return
                }
                UserDefaults.standard.set(changedToTabIndex, forKey: "currentTabId")
                
                allOpenTabsUnique.append(changedToTabIndex)
                UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
                
                FileLogger.shared.log("\(allOpenTabsUnique.elements)")
            }
        }
    }
}

@available(macOSApplicationExtension 12.0, *)
func removeTabFromHistory() {
    let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
    var allOpenTabsUnique = getOpenTabs()
    allOpenTabsUnique.remove(currentTabId)
    UserDefaults.standard.set(allOpenTabsUnique.elements, forKey: "allOpenTabsUnique")
    FileLogger.shared.log("Tab \(currentTabId) removed from history")
}

@available(macOSApplicationExtension 12.0, *)
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

@available(macOSApplicationExtension 12.0, *)
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
        addNewTabToHistory(window: window)
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
