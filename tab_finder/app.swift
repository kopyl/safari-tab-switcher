import SwiftUI
import BackgroundTasks
import AppKit
import Combine
import SafariServices.SFSafariApplication
import SafariServices.SFSafariExtensionManager

let extensionBundleIdentifier = "kopyl.tab-finder-4.Extension"

enum Keys: UInt16 {
    case `return` = 36
    case tab = 48
    case backTick = 50
    case escape = 53
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
    @State private var tabIDsWithTitleAndHost: OrderedSet<TabInfoWithID> = OrderedSet()
    @State private var notificationObserver: NSObjectProtocol?
    @State private var keyMonitors: [Any] = []
    @State private var searchQuery: String = ""

    var filteredTabIDs: [TabInfoWithID] {
            if searchQuery.isEmpty {
                return tabIDsWithTitleAndHost.elements.reversed()
            } else {
                let _searchQuery = searchQuery.lowercased()
                
                let weightedResults = tabIDsWithTitleAndHost.elements.reversed().compactMap { tab -> (tab: TabInfoWithID, score: Int)? in
                    if tab.host == "" { return nil}
                    var score = 0

                    var hostParts = tab.host.split(separator: ".")
                    hostParts = hostParts.filter { $0 != "www" }
                    let domainZone = hostParts.last ?? ""
                    hostParts.removeLast()
                    
                    var scoreMultiplier = 10
                    
                    for hostPartIndex in hostParts.indices {
                        scoreMultiplier -= hostPartIndex
                        if scoreMultiplier < 1 {
                            scoreMultiplier = 1
                        }
                        
                        let hostPart = hostParts.reversed()[hostPartIndex]
                        
                        if hostPart.starts(with: _searchQuery) {
                            score += 5*scoreMultiplier
                        }
                        else if hostPart.localizedCaseInsensitiveContains(searchQuery) {
                            score += 2
                        }
                    }
                    
                    if score == 0 {
                        // if a users types with ".", i need to do at least something
                        if tab.host.localizedCaseInsensitiveContains(searchQuery) {
                            score += 1
                        }
                    }

                    if domainZone.localizedCaseInsensitiveContains(searchQuery) {
                        score += 1
                    }
                    
                    if tab.title.starts(with: _searchQuery) {
                        score += 4
                    }
                    else if tab.title.localizedCaseInsensitiveContains(searchQuery) {
                        score += 1
                    }

                    return score > 0 ? (tab, score) : nil
                }
                
                return weightedResults.sorted { $0.score > $1.score }.map { $0.tab }
            }
        }

    var body: some View {
        VStack {
            TextField("Search tabs...", text: $searchQuery)
                            .padding(10)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: searchQuery) { query in
                                if query.isEmpty {
                                    indexOfTabToSwitchTo = 1
                                } else {
                                    indexOfTabToSwitchTo = 0
                                }
                            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(filteredTabIDs.indices, id: \.self) { id in
                            let tab = filteredTabIDs[id]
                            let pageTitle = tab.title
                            let pageHost = tab.host == "" && pageTitle == "" ? "No title" : tab.host
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
                                .padding(.top, 10).padding(.bottom, id != filteredTabIDs.indices.last ? 10 : 20)
                                .padding(.leading, 10).padding(.trailing, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.blue.opacity(
                                    id == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? 1 : 0))
                                .id(id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    indexOfTabToSwitchTo = id
                                    openSafariAndAskToSwitchTabs()
                                }
                            
                            if id != filteredTabIDs.indices.last && id != filteredTabIDs.indices.first {
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
            tabIDsWithTitleAndHost = Store.tabIDsWithTitleAndHost
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

    func openSafariAndHideTabSwitcherUI() {
        NSApp.hide(nil)
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open(safariURL)
        } else {
            print("Safari is not installed or not found.")
        }
    }

    func setupInAppKeyListener() {
        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if Keys(rawValue: event.keyCode) != nil {
                handleKeyPress(event: event)
                return nil
            }
            if event.keyCode == 51 {
                if !searchQuery.isEmpty {
                    searchQuery.removeLast()
                }
                return nil
            }
            searchQuery.append(event.charactersIgnoringModifiers ?? "")
            return nil
        }
        let keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .flagsChanged]) { event in
            handleKeyRelease(event: event)
            return event
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
        guard !tabIDsWithTitleAndHost.isEmpty else { return }
        guard let key = Keys(rawValue: event.keyCode) else { return }

        switch key {
        case .arrowUp, .backTick:
            indexOfTabToSwitchTo -= 1
        case .tab:
            if event.modifierFlags.contains(.shift) {
                indexOfTabToSwitchTo -= 1
            } else {
                indexOfTabToSwitchTo += 1
            }
        case .arrowDown:
            indexOfTabToSwitchTo += 1
        case .return:
            openSafariAndAskToSwitchTabs()
        case .escape:
            openSafariAndHideTabSwitcherUI()
        }
    }

    func calculateTabToSwitchIndex(_ indexOfTabToSwitchTo: Int) -> Int {
        if filteredTabIDs.isEmpty {
            return 0
        }
        return pythonTrueModulo(indexOfTabToSwitchTo, filteredTabIDs.count)
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
        tabIDsWithTitleAndHost = Store.tabIDsWithTitleAndHost
        searchQuery = ""
        indexOfTabToSwitchTo = 1
        bringWindowToFront()
    }

    private func openSafariAndAskToSwitchTabs() {
        openSafariAndHideTabSwitcherUI()
        if filteredTabIDs.isEmpty{
            openSafariAndHideTabSwitcherUI()
            return
        }
        Task{ await switchTabs() }
    }

    func switchTabs() async {
        let indexOfTabToSwitchToInSafari = filteredTabIDs[calculateTabToSwitchIndex(indexOfTabToSwitchTo)]
        do {
            try await SFSafariApplication.dispatchMessage(
                withName: "switchtabto",
                toExtensionWithIdentifier: extensionBundleIdentifier,
                userInfo: ["id": String(indexOfTabToSwitchToInSafari.id)]
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
