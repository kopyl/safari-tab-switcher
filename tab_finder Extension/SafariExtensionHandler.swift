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
                fetchTabsCount { count in
                    tabCount = count
                }
            }
        }
    }
    
    func fetchTabsCount(completion: @escaping (Int) -> Void) {
            SafariExtensionHandler.getOpenTabsCount(completion: completion)
        }
}

@available(macOSApplicationExtension 11.0, *)
class SafariExtensionHandler: SFSafariExtensionHandler {
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        FileLogger.shared.log(messageName)
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {}

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {

        let currentTabId = UserDefaults.standard.integer(forKey: "currentTabId")
        
        window.getAllTabs { tabs in
            window.getActiveTab { tab in
                if let tab {
                    let changedToTabIndex = tabs.firstIndex(of: tab) ?? currentTabId
                    if changedToTabIndex == currentTabId {
                        return
                    }
                    UserDefaults.standard.set(changedToTabIndex, forKey: "currentTabId")
                    FileLogger.shared.log("Tab changed to id \(changedToTabIndex)")

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

func getAllTabsFromWindow(window: SFSafariWindow) {
    window.getAllTabs(completionHandler: { allTabs in
        print(allTabs)
    })
}
