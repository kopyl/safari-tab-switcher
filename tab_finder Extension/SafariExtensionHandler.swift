import SafariServices
import os.log
import SwiftUI
import UserNotifications

@available(macOS 11.0, *)
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
                SafariExtensionHandler.getOpenTabsCount { count in
                    tabCount = count
                }
            }
        }
    }
}

@available(macOSApplicationExtension 11.0, *)
class SafariExtensionHandler: SFSafariExtensionHandler {
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        FileLogger.shared.log(messageName)
        
        let allOpenTabsUnique = OrderedSet(UserDefaults.standard.array(forKey: "allOpenTabsUnique") as? [Int] ?? [])
        
        guard allOpenTabsUnique.count > 1 else {
                FileLogger.shared.log("No previous tab to switch to.")
                return
            }

        let previousTabId = allOpenTabsUnique[-2]
        FileLogger.shared.log("Switching to previous tab ID: \(previousTabId)")

        SFSafariApplication.getActiveWindow { activeWindow in
            activeWindow?.getAllTabs { tabs in
                guard tabs.indices.contains(previousTabId) else {
                    FileLogger.shared.log("Previous tab ID \(previousTabId) is out of range.")
                    return
                }

                tabs[previousTabId].activate {
                    FileLogger.shared.log("Switching to a tab")
                }
            }
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {}

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")

        var allOpenTabsUnique = OrderedSet(UserDefaults.standard.array(forKey: "allOpenTabsUnique") as? [Int] ?? [])
        
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
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

    static func getOpenTabsCount(completion: @escaping (Int) -> Void) {
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
}
