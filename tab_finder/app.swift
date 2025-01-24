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

struct TabForSearch {
    var id: Int
    var title: String
    var host: String
    var hostParts: [String.SubSequence] = []
    var domainZone: String.SubSequence = ""
    var searchRating: Int = 0
    
    
    init(tab: Tab){
        id = tab.id
        title = tab.title
        host = tab.host == "" && title == "" ? "No title" : tab.host
        
        
        hostParts = host.split(separator: ".")
        hostParts = hostParts.filter { $0 != "www" }
        domainZone = hostParts.last ?? ""
        guard !hostParts.isEmpty else { return }
        hostParts.removeLast()
        hostParts = hostParts.reversed()
    }
}

struct TabHistoryView: View {
    @State private var indexOfTabToSwitchTo: Int = 1
    @State private var tabIDsWithTitleAndHost = Tabs()
    @State private var notificationObserver: NSObjectProtocol?
    @State private var keyMonitors: [Any] = []
    @State private var searchQuery: String = ""
    
    @State private var filteredTabs: [TabForSearch] = []
    
    @Environment(\.scenePhase) var scenePhase
    
    func filterTabs() {
        filteredTabs = tabIDsWithTitleAndHost.reversed().map{TabForSearch(tab: $0)}
        guard !searchQuery.isEmpty else { return }
        
        let _searchQuery = searchQuery.lowercased()
        
        let _filteredTabs = filteredTabs.filter {
            $0.host.localizedCaseInsensitiveContains(searchQuery) ||
            $0.title.localizedCaseInsensitiveContains(searchQuery)
        }
        
        let weightedResults = _filteredTabs.compactMap { tab -> (tab: TabForSearch, score: Int)? in
            var tab = tab
            let host = tab.host
            
            tab.searchRating = 0
            
            var scoreMultiplier = 10
            
            for hostPartIndex in tab.hostParts.indices {
                scoreMultiplier -= hostPartIndex
                
                if scoreMultiplier < 1 {
                    scoreMultiplier = 1
                }
                
                let hostPart = tab.hostParts[hostPartIndex]
                
                if hostPart == "No title" {
                    continue
                }
                
                if hostPart.starts(with: _searchQuery) {
                    tab.searchRating += 5*scoreMultiplier
                }
                else if hostPart.localizedCaseInsensitiveContains(searchQuery) {
                    tab.searchRating += 2
                }
            }
            
            if tab.searchRating == 0 {
                if host.localizedCaseInsensitiveContains(searchQuery) {
                    tab.searchRating += 1
                }
            }

            if tab.domainZone.localizedCaseInsensitiveContains(searchQuery) {
                tab.searchRating += 1
            }
            
            if tab.title.starts(with: _searchQuery) {
                tab.searchRating += 4
            }
            else if tab.title.localizedCaseInsensitiveContains(searchQuery) {
                tab.searchRating += 1
            }

            return tab.searchRating > 0 ? (tab, tab.searchRating) : nil
        }
        
        filteredTabs = weightedResults.sorted { $0.tab.searchRating > $1.tab.searchRating }.map { $0.tab }
    }

    var body: some View {
        VStack(spacing: -5) {
            let tabsCount = tabIDsWithTitleAndHost.count
            HStack(spacing: 15){
                Image(systemName: "magnifyingglass")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.gray)
                    .font(.system(size: 22))
                CustomTextField(
                    text: $searchQuery,
                    placeholder: "Search among ^[\(tabsCount) \("tab")](inflect: true)"
                )
            }
            .padding(.leading, 20)
            .padding(.top, -12)
            .padding(.trailing, 20)
            .padding(.bottom, 26)
            
            Divider().background(.gray.opacity(0.01))

            .onChange(of: searchQuery) { query in
                if query.isEmpty {
                    indexOfTabToSwitchTo = 1
                } else {
                    indexOfTabToSwitchTo = 0
                }
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTabs.indices, id: \.self) { id in
                            let tab = filteredTabs[id]
                            let pageTitle = tab.title
                            let pageHost = tab.host
                            let pageTitleFormatted = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let pageHostFormatted = formatHost(pageHost)

                            VStack(alignment: .leading, spacing: 10) {
                                Text(pageHostFormatted)
                                .font(.system(size: 25))
                                .foregroundStyle(
                                    id == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? .white : .primary.opacity(0.9)
                                )
                                
                                Text(pageTitleFormatted)
                                .font(.system(size: 13))
                                .foregroundStyle(
                                    id == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? .white : Color.primary
                                )
                                .opacity(0.65)
                            }
                                .lineLimit(1)
                                .padding(.top, 20).padding(.bottom, 20)
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
                            
                            if id != filteredTabs.indices.last {
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
        .task {
            hideAppControls()
        }
        .onChange(of: scenePhase) { phase in
            guard !NSEvent.modifierFlags.contains(.option) else { return }
            openSafariAndAskToSwitchTabs()
        }
    }

    func hideAppControls() {
        if let window = NSApp.windows.first {
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            window.setContentSize(NSSize(width: 800, height: 1400))
            window.center()
            
            let titlebarBlurView = VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)._makeNSView()
            let titlebarFrame = NSRect(x: 0, y: window.frame.height - 28, width: window.frame.width, height: 28)
            titlebarBlurView.frame = titlebarFrame
            titlebarBlurView.autoresizingMask = [.width, .minYMargin]
            window.contentView?.superview?.addSubview(titlebarBlurView, positioned: .below, relativeTo: window.contentView)
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
                    filterTabs()
                }
                return nil
            }
            searchQuery.append(event.charactersIgnoringModifiers ?? "")
            filterTabs()
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
        if filteredTabs.isEmpty {
            return 0
        }
        return pythonTrueModulo(indexOfTabToSwitchTo, filteredTabs.count)
    }

    private func bringWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
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
        filterTabs()
        indexOfTabToSwitchTo = 1
        bringWindowToFront()
    }

    private func openSafariAndAskToSwitchTabs() {
        openSafariAndHideTabSwitcherUI()
        if filteredTabs.isEmpty{
            openSafariAndHideTabSwitcherUI()
            return
        }
        Task{ await switchTabs() }
    }

    func switchTabs() async {
        let indexOfTabToSwitchToInSafari = filteredTabs[calculateTabToSwitchIndex(indexOfTabToSwitchTo)]
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

@main
struct MySafariApp: App {
    var body: some Scene {
        WindowGroup {
            TabHistoryView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
