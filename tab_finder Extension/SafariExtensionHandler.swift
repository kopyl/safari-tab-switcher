import SafariServices
import os.log
import SwiftUI
import UserNotifications

@available(macOSApplicationExtension 10.15, *)
struct HelloWorldView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
                .font(.largeTitle)
                .padding()
            Button("Close") {
            }
            .padding()
        }
    }
}

func sendNotification(subtitle: String) {
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


@available(macOSApplicationExtension 10.15, *)
class SafariExtensionHandler: SFSafariExtensionHandler {

    override func toolbarItemClicked(in window: SFSafariWindow) {
        os_log(.default, "Toolbar item clicked")
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        validationHandler(true, "") // Enable toolbar item
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        // Return the shared instance of the popover
        return SafariExtensionViewController.shared
    }
}
