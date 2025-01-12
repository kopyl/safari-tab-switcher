import SwiftUI
import BackgroundTasks

struct HelloWorldView: View {
    @State private var notificationObserver: NSObjectProtocol?
    
    var body: some View {
        EmptyView()
        .onAppear {
            setupDistributedNotificationListener()
        }
        .onDisappear {
            removeDistributedNotificationListener()
        }
    }
    
    private func bringWindowToFront() {
        if let window = NSApplication.shared.windows.first {
            window.orderFrontRegardless()
        }
    }
    
    private func removeDistributedNotificationListener() {
            if let observer = notificationObserver {
                DistributedNotificationCenter.default().removeObserver(observer)
                log("Distributed Notification Listener Removed")
            }
        }
    
    private func setupDistributedNotificationListener() {
            let notificationName = Notification.Name("com.tabfinder.example.notification")
            
            notificationObserver = DistributedNotificationCenter.default().addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { notification in
                handleNotification(notification)
            }
            log("Distributed Notification Listener Set Up")
        }

    private func handleNotification(_ notification: Notification) {
        log("Distributed Notification Received in App")
        let savedTabTitles = Store.allOpenTabsUniqueWithTitles
        log(savedTabTitles)
        bringWindowToFront()
    }
}

@main
struct MySafariApp: App {
    var body: some Scene {
        WindowGroup {
            HelloWorldView()
        }
    }
}
