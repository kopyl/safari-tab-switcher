import SwiftUI
import SafariServices.SFSafariExtensionManager

func switchTabs() async {
    let tabToSwitchToInSafari = appState.filteredTabs[appState.indexOfTabToSwitchTo]
    do {
        addSpecificTabToHistory(tab: tabToSwitchToInSafari)
        try await SFSafariApplication.dispatchMessage(
            withName: "switchtabto",
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: ["id": String(tabToSwitchToInSafari.safariID)]
        )
    } catch let error {
        log("Dispatching message to the extension resulted in an error: \(error)")
    }
}

func addSpecificTabToHistory(tab: TabForSearch) {
    var windows = Store.windows
    guard var tabsMutated = windows.windows.last?.tabs else { return }
    
    let tabIDsWithTitleAndHost = Tab(tab: tab)

    tabsMutated.append(tabIDsWithTitleAndHost)

    let currentWindow = _Window(tabs: tabsMutated)
    windows.append(currentWindow)
    Store.windows = windows
}

func hideTabsPanelAndSwitchTabs() {
    hideTabsPanel()
    guard !appState.filteredTabs.isEmpty else { return }
    Task{ await switchTabs() }
}

func filterTabs() {
    
    guard !appState.searchQuery.isEmpty else {
        appState.filteredTabs = appState.tabIDsWithTitleAndHost.reversed()
            .enumerated()
            .map { TabForSearch(tab: $1, id: $0) }
        return
    }
    
    appState.filteredTabs = appState.tabIDsWithTitleAndHost.reversed()
    .map { TabForSearch(tab: $0, id: 0) }
    
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
    
    appState.filteredTabs = weightedResults.sorted { $0.tab.searchRating > $1.tab.searchRating }
        .enumerated()
        .map { TabForSearch(tab: Tab(tab: $1.tab), id: $0) }
}

struct TabItemView: View {
    @ObservedObject var state = appState
    let tab: TabForSearch
    
    var body: some View {
        HStack(alignment: .center) {
            Text(tab.host)
                .font(.system(size: 18))
                .foregroundStyle(
                    tab.id == state.indexOfTabToSwitchTo ? .currentTabFg : .currentTabFg.opacity(0.65)
                )
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            Text(tab.title)
                .font(.system(size: 13))
                .foregroundStyle(
                    tab.id == state.indexOfTabToSwitchTo ? .currentTabFg : .currentTabFg.opacity(0.65)
                )
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .lineLimit(1)
        .padding(.top, 18).padding(.bottom, 18)
        .padding(.leading, 21).padding(.trailing, 21)
        .background(
            .currentTabBg.opacity(tab.id == state.indexOfTabToSwitchTo ? 1 : 0)
        )
        .id(tab.id)
        .contentShape(Rectangle())
        .cornerRadius(6)
        .frame(minWidth: 0, maxWidth: .infinity)
        .onTapGesture {
            state.indexOfTabToSwitchTo = tab.id
            hideTabsPanelAndSwitchTabs()
        }
        .onMouseMove {
            state.indexOfTabToSwitchTo = tab.id
        }
    }
}

struct TabListView: View {
    @Binding var proxy: ScrollViewProxy?
    @ObservedObject var state = appState
    
    var body: some View {
        ScrollViewReader { _proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(state.filteredTabs) { tab in
                        TabItemView(tab: tab)
                    }
                    .padding(.bottom, 4)
                }
                /// https://github.com/kopyl/safari-tab-switcher/issues/6#issuecomment-2742046807
                .padding(.horizontal, 4)
            }
            .onAppear {
                proxy = _proxy
            }
        }
    }
}

struct TabHistoryView: View {
    @State private var keyMonitors: [Any] = []
    @ObservedObject var appState: AppState
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    
    @State var proxy: ScrollViewProxy?
    
    var greyInDarkAppearance: Color = .white.opacity(0.4)
    var greyInLightAppearance: Color = .black.opacity(0.4)
    
    var grey: Color {
        colorScheme == .dark ? greyInDarkAppearance : greyInLightAppearance
    }
    
    @AppStorage(
        Store.isTabsSwitcherNeededToStayOpenStoreKey,
        store: Store.userDefaults
    ) private var isTabsSwitcherNeededToStayOpen: Bool = false
    
    @AppStorage(
        Store.userSelectedAccentColorStoreKey,
        store: Store.userDefaults
    ) private var userSelectedAccentColor: String = Store.userSelectedAccentColorDefaultValue

    var body: some View {
        VStack {
            ZStack {
                if userSelectedAccentColor != Store.userSelectedAccentColorDefaultValue {
                    Rectangle().fill(hexToColor(userSelectedAccentColor).opacity(0.15))
                }
                VStack {
                    let tabsCount = appState.tabIDsWithTitleAndHost.count
                    HStack(spacing: 10){
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(grey)
                            .font(.system(size: 22))
                        CustomTextField(
                            text: $appState.searchQuery,
                            placeholder: "Search among ^[\(tabsCount) \("tab")](inflect: true)"
                        )
                        Image(systemName: isTabsSwitcherNeededToStayOpen ? "pin.fill" : "pin")
                            .foregroundStyle(grey)
                            .font(.system(size: 22))
                            .frame(width: 69, height: 72)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isTabsSwitcherNeededToStayOpen.toggle()
                                if !isTabsSwitcherNeededToStayOpen {
                                    guard !isUserHoldingShortcutModifiers() else { return }
                                    hideTabsPanel()
                                }
                            }
                    }
                    .padding(.leading, 24)
                    TabListView(proxy: $proxy)
                }
            }
        }
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))

        .onAppear {
            setupInAppKeyListener()
            appState.isTabsSwitcherNeededToStayOpen = isTabsSwitcherNeededToStayOpen
        }
        .onDisappear {
            removeInAppKeyListener()
        }
        .onChange(of: appState.isTabsPanelOpen) { isOpen in
            if isOpen {
                proxy?.scrollTo(appState.indexOfTabToSwitchTo, anchor: .bottom)
            }
        }
        .onChange(of: appState.searchQuery) { query in
            filterTabs()
            appState.indexOfTabToSwitchTo = query.isEmpty ? 1 : 0
            scrollToSelectedTab()
        }
        .onChange(of: scenePhase) { phase in
            guard !isUserHoldingShortcutModifiers() else { return }
            hideTabsPanelAndSwitchTabs()
        }
        .onChange(of: isTabsSwitcherNeededToStayOpen) { newValue in
            appState.isTabsSwitcherNeededToStayOpen = newValue
        }
    }
    
    func scrollToSelectedTab() {
        proxy?.scrollTo(appState.indexOfTabToSwitchTo)
    }

    func setupInAppKeyListener() {
        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard NSApp.keyWindow?.identifier == tabsPanelID else { return event }
            if NavigationKeys(rawValue: event.keyCode) != nil {
                handleNavigationKeyPresses(event: event)
                return nil
            }
            return event
        }
        let keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .flagsChanged]) { event in
            guard NSApp.keyWindow?.identifier == tabsPanelID else { return event }
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
        guard isTabsSwitcherNeededToStayOpen == false else { return }
        guard !isUserHoldingShortcutModifiers(event: event) else { return }
        hideTabsPanelAndSwitchTabs()
    }

    func handleNavigationKeyPresses(event: NSEvent) {
        guard isUserHoldingShortcutModifiers(event: event) || isTabsSwitcherNeededToStayOpen else { return }
        guard !appState.tabIDsWithTitleAndHost.isEmpty else { return }
        guard let key = NavigationKeys(rawValue: event.keyCode) else { return }

        switch key {
        case .arrowUp, .backTick:
            appState.indexOfTabToSwitchTo -= 1
            scrollToSelectedTab()
        case .tab:
            if event.modifierFlags.contains(.shift) {
                appState.indexOfTabToSwitchTo -= 1
            } else {
                appState.indexOfTabToSwitchTo += 1
            }
            scrollToSelectedTab()
        case .arrowDown:
            appState.indexOfTabToSwitchTo += 1
            scrollToSelectedTab()
        case .return:
            hideTabsPanelAndSwitchTabs()
        case .escape:
            hideTabsPanel(withoutAnimation: true)
        }
    }
}
