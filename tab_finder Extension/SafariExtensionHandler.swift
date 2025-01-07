import SafariServices
import os.log
import SwiftUI
import UserNotifications

@available(macOSApplicationExtension 11.0, *)
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
                    os_log("Tab changed to id \(changedToTabIndex)")

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

func sendNotification(_ subtitle: String) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
        if success {
            print("Permission approved!")
        } else if let error = error {
            print(error.localizedDescription)
        }
    }
    
    let content = UNMutableNotificationContent()
    content.title = "Notification"
    content.subtitle = subtitle
    content.sound = UNNotificationSound.default

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
}

func getAllTabsFromWindow(window: SFSafariWindow) {
    window.getAllTabs(completionHandler: { allTabs in
        print(allTabs)
    })
}

func navigateToUrl(window: SFSafariWindow, url: String) {
    window.getActiveTab(completionHandler: { (tab) in
        if let myUrl = URL(string: url){
            tab?.navigate(to: myUrl)
        }
    })
}
