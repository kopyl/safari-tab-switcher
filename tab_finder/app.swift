import SwiftUI
import BackgroundTasks

struct HelloWorldView: View {
    @State private var indexOfTabToSwitchTo: Int = 0
    @State private var allOpenTabsUnique: [Int] = []
    @State private var savedTabTitles: [String: String] = [:]
    @State private var notificationObserver: NSObjectProtocol?
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        let tabsToDisplay = Array(allOpenTabsUnique.reversed())
                        ForEach(tabsToDisplay.indices, id: \.self) { tabIdx in
                            Text(savedTabTitles[String(tabsToDisplay[tabIdx])] ?? "No title")
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
            savedTabTitles = Store.allOpenTabsUniqueWithTitles
            allOpenTabsUnique = OrderedSet(Store.allOpenTabsUnique).elements
        }
        .onAppear {
            setupDistributedNotificationListener()
            setupInAppKeyListener()
        }
        .onDisappear {
            removeDistributedNotificationListener()
            removeInAppKeyListener()
        }
    }
    
    func setupInAppKeyListener() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            handleKeyPress(event: event)
        }
    }

    func removeInAppKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func handleKeyPress(event: NSEvent) {
        guard !allOpenTabsUnique.isEmpty else { return }
        
        // released option
        if event.modifierFlags.rawValue == 256 && event.keyCode == 58 {
            bringWindowToBack()
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
        if let window = NSApplication.shared.windows.first {
            window.orderFrontRegardless()
        }
    }
    
    private func bringWindowToBack() {
        if let window = NSApplication.shared.windows.first {
            window.orderBack(nil)
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
        savedTabTitles = Store.allOpenTabsUniqueWithTitles
        allOpenTabsUnique = Store.allOpenTabsUnique
        log(savedTabTitles)
        log(allOpenTabsUnique)
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
        indexOfTabToSwitchTo = 0
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
