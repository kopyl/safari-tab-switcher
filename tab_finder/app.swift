import SwiftUI
import BackgroundTasks
import AppKit
import Combine
import SafariServices.SFSafariApplication
import SafariServices.SFSafariExtensionManager

let extensionBundleIdentifier = "kopyl.tab-finder-5.Extension"

enum Keys: UInt16 {
    case `return` = 36
    case tab = 48
    case backTick = 50
    case arrowDown = 125
    case arrowUp = 126
}

func formatHost(_ host: String) -> String {
    return host
        .replacingOccurrences(of: "www.", with: "", options: NSString.CompareOptions.literal, range: nil)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

struct HelloWorldView: View {
    @State private var indexOfTabToSwitchTo: Int = 1
    @State private var allOpenTabsUnique: [Int] = []
    @State private var savedTabTitlesAndHosts: TabsStorage = [:]
    @State private var notificationObserver: NSObjectProtocol?
    @State private var keyMonitors: [Any] = []
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        let tabsToDisplay = Array(allOpenTabsUnique.reversed())

                        ForEach(tabsToDisplay.indices, id: \.self) { tabIdx in
                            let pageTitleAndHost = savedTabTitlesAndHosts[String(tabsToDisplay[tabIdx])]
                            let pageTitle = pageTitleAndHost?.title ?? ""
                            let pageHost = pageTitleAndHost?.host ?? "" == "" && pageTitle == "" ? "Start page" : pageTitleAndHost?.host ?? ""
                            let pageTitleFormatted = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let pageHostFormatted = formatHost(pageHost)

                            
                            VStack(alignment: .leading, spacing: 15) {
                                Text(pageHostFormatted)
                                .font(.system(size: 18))
                                
                                Text(pageTitleFormatted)
                                .font(.system(size: 12))
                                .opacity(0.65)
                            }
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
                                    openSafariAndAskToSwitchTabs()
                                }
                            
                            if tabIdx != tabsToDisplay.indices.last && tabIdx != tabsToDisplay.indices.first {
                                Divider().background(.gray.opacity(0.01))
                            }
                        }
                    }
                    .frame(minWidth: 800)
                }
                .onChange(of: indexOfTabToSwitchTo) { newIndex in
                    withAnimation {
                        proxy.scrollTo(calculateTabToSwitchIndex(newIndex), anchor: .bottom)
                    }
                }
            }
        }
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))


        .onAppear {
            savedTabTitlesAndHosts = Store.allOpenTabsUniqueWithTitlesAndHosts
            allOpenTabsUnique = OrderedSet(Store.allOpenTabsUnique).elements
            NSApp.hide(nil)
            NSApp.setActivationPolicy(.accessory)
            setupDistributedNotificationListener()
            setupInAppKeyListener()
        }
        .onDisappear {
            removeDistributedNotificationListener()
            removeInAppKeyListener()
        }
    }
    
    func hideAppControls() {
        if let window = NSApp.windows.first {
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            
            window.setContentSize(NSSize(width: 800, height: 1400))
            window.center()
        }
    }
    
    func openSafari() {
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open(safariURL)
        } else {
            print("Safari is not installed or not found.")
        }
    }
    
    func setupInAppKeyListener() {
        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyPress(event: event)
            return nil
        }
        let keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .flagsChanged]) { event in
            handleKeyRelease(event: event)
            return nil
        }
        if let keyUpMonitor, let keyDownMonitor {
            keyMonitors.append(contentsOf: [keyUpMonitor, keyDownMonitor])
        }
    }

    func removeInAppKeyListener() {
        for monitor in keyMonitors {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitors = []
    }
    
    func handleKeyRelease(event: NSEvent) {
        guard !event.modifierFlags.contains(.option) else { return }
        openSafariAndAskToSwitchTabs()
    }
    
    func handleKeyPress(event: NSEvent) {
        guard event.modifierFlags.contains(.option) else { return }
        guard !allOpenTabsUnique.isEmpty else { return }
        
        switch Keys(rawValue: event.keyCode) {
        case .arrowUp, .backTick:
            indexOfTabToSwitchTo -= 1
        case .arrowDown, .tab:
            indexOfTabToSwitchTo += 1
        case .return:
            openSafariAndAskToSwitchTabs()
        default:
            break
        }
    }
    
    func calculateTabToSwitchIndex(_ indexOfTabToSwitchTo: Int) -> Int {
        return pythonTrueModulo(indexOfTabToSwitchTo, allOpenTabsUnique.count)
    }
    
    private func bringWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        hideAppControls()
    }
    
    private func removeDistributedNotificationListener() {
            if let observer = notificationObserver {
                DistributedNotificationCenter.default().removeObserver(observer)
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
        }

    private func handleNotification(_ notification: Notification) {
        savedTabTitlesAndHosts = Store.allOpenTabsUniqueWithTitlesAndHosts
        allOpenTabsUnique = Store.allOpenTabsUnique
        indexOfTabToSwitchTo = 1
        bringWindowToFront()
    }
    
    private func openSafariAndAskToSwitchTabs() {
        NSApp.hide(nil)
        openSafari()
        Task{ await sendMessageToExtensionAskingToSwitchTabs() }
    }
    
    func sendMessageToExtensionAskingToSwitchTabs() async {
        do {
            try await SFSafariApplication.dispatchMessage(
                withName: "switchtabto",
                toExtensionWithIdentifier: extensionBundleIdentifier,
                userInfo: ["id": String(calculateTabToSwitchIndex(indexOfTabToSwitchTo))]
            )
        } catch let error {
            log("Dispatching message to the extension resulted in an error: \(error)")
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
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
