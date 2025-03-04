import SwiftUI
import SafariServices.SFSafariExtensionManager
import HotKey

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

func filterTabs() {
    appState.filteredTabs = appState.tabIDsWithTitleAndHost.reversed().map{TabForSearch(tab: $0)}
    guard !appState.searchQuery.isEmpty else { return }
    
    let _searchQuery = appState.searchQuery.lowercased()
    
    let _filteredTabs = appState.filteredTabs.filter {
        $0.host.localizedCaseInsensitiveContains(appState.searchQuery) ||
        $0.title.localizedCaseInsensitiveContains(appState.searchQuery)
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
            else if hostPart.localizedCaseInsensitiveContains(appState.searchQuery) {
                tab.searchRating += 2
            }
        }
        
        if tab.searchRating == 0 {
            if host.localizedCaseInsensitiveContains(appState.searchQuery) {
                tab.searchRating += 1
            }
        }

        if tab.domainZone.localizedCaseInsensitiveContains(appState.searchQuery) {
            tab.searchRating += 1
        }
        
        if tab.title.starts(with: _searchQuery) {
            tab.searchRating += 4
        }
        else if tab.title.localizedCaseInsensitiveContains(appState.searchQuery) {
            tab.searchRating += 1
        }

        return tab.searchRating > 0 ? (tab, tab.searchRating) : nil
    }
    
    appState.filteredTabs = weightedResults.sorted { $0.tab.searchRating > $1.tab.searchRating }.map(\.tab)
}

struct TabHistoryView: View {
    var hotKey: HotKey
    @State private var keyMonitors: [Any] = []
    @ObservedObject var appState: AppState
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = false

    var body: some View {
        VStack {
            let tabsCount = appState.tabIDsWithTitleAndHost.count
            HStack(spacing: 15){
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)
                    .font(.system(size: 22))
                CustomTextField(
                    text: $appState.searchQuery,
                    placeholder: "Search among ^[\(tabsCount) \("tab")](inflect: true)"
                )
                Image(systemName: isTabsSwitcherNeededToStayOpen ? "pin.fill" : "pin")
                    .foregroundStyle(.gray)
                    .font(.system(size: 22))
                    .frame(width: 69, height: 72)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isTabsSwitcherNeededToStayOpen.toggle()
                        if !isTabsSwitcherNeededToStayOpen {
                            hideTabSwitcherUI()
                        }
                    }
            }
            .padding(.leading, 20)

            .onChange(of: appState.searchQuery) { query in
                appState.indexOfTabToSwitchTo = query.isEmpty ? 1 : 0
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.filteredTabs.indices, id: \.self) { id in
                            let tab = appState.filteredTabs[id]
                            let pageTitle = tab.title
                            let pageHost = tab.host
                            let pageTitleFormatted = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let pageHostFormatted = formatHost(pageHost)

                            HStack(alignment: .center) {
                                Text(pageHostFormatted)
                                .font(.system(size: 18))
                                .foregroundStyle(
                                    id == calculateTabToSwitchIndex(appState.indexOfTabToSwitchTo)
                                    ? .currentTabFg : .primary.opacity(0.9)
                                )
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                
                                Text(pageTitleFormatted)
                                .font(.system(size: 13))
                                .foregroundStyle(
                                    id == calculateTabToSwitchIndex(appState.indexOfTabToSwitchTo)
                                    ? .currentTabFg : Color.primary
                                )
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .opacity(0.65)
                            }
                                .lineLimit(1)
                                .padding(.top, 14).padding(.bottom, 14)
                                .padding(.leading, 18).padding(.trailing, 18)
                                .background(
                                    .currentTabBg.opacity(
                                        id == calculateTabToSwitchIndex(appState.indexOfTabToSwitchTo)
                                        ? 1 : 0)
                                )
                                .id(id)
                                .contentShape(Rectangle())
                                .cornerRadius(6)
                            
                                .frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, maxWidth: .infinity)
                                .padding(4)
                            
                                .onTapGesture {
                                    appState.indexOfTabToSwitchTo = id
                                    openSafariAndAskToSwitchTabs()
                                }
                        }
                    }
                }
                .onChange(of: appState.indexOfTabToSwitchTo) { newIndex in
                    withAnimation {
                        proxy.scrollTo(calculateTabToSwitchIndex(newIndex), anchor: .bottom)
                    }
                }
            }
        }
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))

        .onAppear {
            setupInAppKeyListener()
        }
        .onDisappear {
            removeInAppKeyListener()
        }
        .onChange(of: appState.searchQuery) { _ in
            filterTabs()
        }
        .onChange(of: scenePhase) { phase in
            guard appState.isUserOnboarded == true else { return }
            guard !NSEvent.modifierFlags.contains(.option) else { return }
            openSafariAndAskToSwitchTabs()
        }
    }

    func setupInAppKeyListener() {
        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard NSApp.keyWindow?.identifier == tabsWindowID else { return event }
            if NavigationKeys(rawValue: event.keyCode) != nil {
                handleNavigationKeyPresses(event: event)
                return nil
            }
            return event
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
        guard appState.isUserOnboarded else { return }
        guard isTabsSwitcherNeededToStayOpen == false else { return }
        guard !event.modifierFlags.contains(.option) else { return }
        openSafariAndAskToSwitchTabs()
    }
    
    func hideTabSwitcherUI() {
        NSApp.hide(nil)
        tabsWindow?.orderOut(nil)
    }
    
    func openSafari() {
        hideTabSwitcherUI()
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open(safariURL)
        }
    }

    func handleNavigationKeyPresses(event: NSEvent) {
        guard event.modifierFlags.contains(.option) || isTabsSwitcherNeededToStayOpen else { return }
        guard !appState.tabIDsWithTitleAndHost.isEmpty else { return }
        guard let key = NavigationKeys(rawValue: event.keyCode) else { return }

        switch key {
        case .arrowUp, .backTick:
            appState.indexOfTabToSwitchTo -= 1
        case .tab:
            if event.modifierFlags.contains(.shift) {
                appState.indexOfTabToSwitchTo -= 1
            } else {
                appState.indexOfTabToSwitchTo += 1
            }
        case .arrowDown:
            appState.indexOfTabToSwitchTo += 1
        case .return:
            openSafariAndAskToSwitchTabs()
        case .escape:
            hideTabSwitcherUI()
        }
    }

    func calculateTabToSwitchIndex(_ indexOfTabToSwitchTo: Int) -> Int {
        if appState.filteredTabs.isEmpty {
            return 0
        }
        return pythonTrueModulo(indexOfTabToSwitchTo, appState.filteredTabs.count)
    }

    private func openSafariAndAskToSwitchTabs() {
        hideTabSwitcherUI()
        openSafari()
        guard !appState.filteredTabs.isEmpty else { return }
        Task{ await switchTabs() }
    }

    func switchTabs() async {
        let indexOfTabToSwitchToInSafari = appState.filteredTabs[calculateTabToSwitchIndex(appState.indexOfTabToSwitchTo)]
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
