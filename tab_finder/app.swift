import SwiftUI
import BackgroundTasks

struct HelloWorldView: View {
    @State private var indexOfTabToSwitchTo: Int = 0
    @State private var allOpenTabsUnique: [Int] = []
    @State private var savedTabTitlesAndHosts: [String: [String: String]] = [:]
    @State private var notificationObserver: NSObjectProtocol?
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        let tabsToDisplay = Array(allOpenTabsUnique.reversed())
                        ForEach(tabsToDisplay.indices, id: \.self) { tabIdx in
                            let pageTitleAndHost = savedTabTitlesAndHosts[String(tabsToDisplay[tabIdx])]
                            let pageTitle = pageTitleAndHost?["title"] ?? "No title"
                            let pageHost = pageTitleAndHost?["host"] ?? ""
                            
                            Text(pageHost)
                                .font(.system(size: 15))
                                .lineLimit(1)
                                .padding(.top, 10).padding(.bottom, tabIdx != tabsToDisplay.indices.last ? 10 : 20)
                                .padding(.leading, 10).padding(.trailing, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.blue.opacity(
                                    tabIdx == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? 1 : 0))
                                .id(tabIdx)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    indexOfTabToSwitchTo = tabIdx
//                                    switchToTab()
                                }
                            
                            if tabIdx != tabsToDisplay.indices.last && tabIdx != tabsToDisplay.indices.first {
                                Divider().background(.gray.opacity(0.01))
                            }
                        }
                    }
                }
                .onChange(of: indexOfTabToSwitchTo) { newIndex in
                    withAnimation {
                        proxy.scrollTo(calculateTabToSwitchIndex(newIndex), anchor: .bottom)
                    }
                }
            }
        }
        .task {
            savedTabTitlesAndHosts = Store.allOpenTabsUniqueWithTitlesAndHosts
            allOpenTabsUnique = OrderedSet(Store.allOpenTabsUnique).elements
        }
        .onAppear {
            NSApp.setActivationPolicy(.accessory)
            setupDistributedNotificationListener()
            setupInAppKeyListener()
        }
        .onDisappear {
            removeDistributedNotificationListener()
            removeInAppKeyListener()
        }
    }
    
    func setupInAppKeyListener() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            handleKeyPress(event: event)
            return event
        }
    }

    func removeInAppKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func openSafari() {
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open(safariURL)
        } else {
            print("Safari is not installed or not found.")
        }
    }
    
    func handleKeyPress(event: NSEvent) {
        guard !allOpenTabsUnique.isEmpty else { return }
        
        // released option
        if event.modifierFlags.rawValue == 256 && event.keyCode == 58 {
            openSafari()
            postDistributedNotification()
            return
        }
        
        // pressed option
        if event.modifierFlags.rawValue != 524576 {
            return
        }
        
        switch event.type {
        case .keyDown:
            switch event.keyCode {
            case 126:
                indexOfTabToSwitchTo -= 1
            case 50:  // `
                indexOfTabToSwitchTo -= 1
            case 125:
                indexOfTabToSwitchTo += 1
            case 48: // tab
                indexOfTabToSwitchTo += 1
            case 36: // tab
                "Return"
            default:
                break
            }
        default:
            break
        }
    }
    
    func calculateTabToSwitchIndex(_ indexOfTabToSwitchTo: Int) -> Int {
        return pythonTrueModulo(indexOfTabToSwitchTo, allOpenTabsUnique.count)
    }
    
    private func bringWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
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
        savedTabTitlesAndHosts = Store.allOpenTabsUniqueWithTitlesAndHosts
        allOpenTabsUnique = Store.allOpenTabsUnique
        bringWindowToFront()
    }
    
    private func postDistributedNotification() {
        let notificationName = Notification.Name("com.tabfinder-toExtension.example.notification")
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: String(calculateTabToSwitchIndex(indexOfTabToSwitchTo)),
            deliverImmediately: true
        )
        log(calculateTabToSwitchIndex(indexOfTabToSwitchTo))
        indexOfTabToSwitchTo = 1
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
