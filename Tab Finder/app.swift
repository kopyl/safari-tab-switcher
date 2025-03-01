import SwiftUI
import HotKey
import SafariServices.SFSafariExtensionManager

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

struct OnboardingImage: View {
    var name: String
    
    var body: some View {
        if let onboardingImageLeft = NSImage(named: name) {
            Image(nsImage: onboardingImageLeft)
                .resizable()
                .scaledToFit()
                .frame(height: 458)
        }
    }
}

func startUsingTabFinder() {
    guard let greetingWindow else {
        return
    }
    greetingWindow.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
}

func hideMainWindow() {
    tabsWindow?.orderOut(nil)
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
    
    appState.filteredTabs = weightedResults.sorted { $0.tab.searchRating > $1.tab.searchRating }.map { $0.tab }
}

struct GreetingView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack {
            HStack(spacing: 33) {
                OnboardingImage(name: AssetNames.Onboarding.left)
                OnboardingImage(name: AssetNames.Onboarding.right)
            }
            .padding(.top, 41)
            Spacer()
            Text(Copy.Onboarding.description)
                .font(.title3)
                .padding(.top, 6)
                .padding(.bottom, 5)
            Spacer()
            
            VStack {
                OnboardingButton {
                    startUsingTabFinder()
                    appState.isUserOnboarded = true
                }
                .padding(.bottom, 10)
                Text(Copy.Onboarding.buttonHint)
                    .font(.system(size: 12))
                    .opacity(0.6)
            }
            .padding(.bottom, 41)
            .padding(.horizontal, 41)
        }
        .onDisappear {
            startUsingTabFinder()
            appState.isUserOnboarded = true
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TabHistoryView: View {
    var hotKey: HotKey
    @State private var keyMonitors: [Any] = []
    @ObservedObject var appState: AppState
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
    @State private var scrollViewHeight: CGFloat = 0
    @State private var scrollViewContentHeight: CGFloat = 0
    @State private var itemPositions: [Int: CGRect] = [:]
    @State private var isUserNearEdge: Bool = false
    @State private var lastScrollPosition: CGFloat = 0
    
    func setUp() {
        setupInAppKeyListener()
    }

    var body: some View {
        VStack(spacing: -5) {
            let tabsCount = appState.tabIDsWithTitleAndHost.count
            HStack(spacing: 15){
                Image(systemName: "magnifyingglass")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.gray)
                    .font(.system(size: 22))
                CustomTextField(
                    text: $appState.searchQuery,
                    placeholder: "Search among ^[\(tabsCount) \("tab")](inflect: true)"
                )
            }
            .padding(.leading, 20)
            .padding(.top, 16)
            .padding(.trailing, 20)
            .padding(.bottom, 26)

            .onChange(of: appState.searchQuery) { query in
                if query.isEmpty {
                    appState.indexOfTabToSwitchTo = 1
                } else {
                    appState.indexOfTabToSwitchTo = 0
                }
            }
            
            GeometryReader { scrollViewGeometry in
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        GeometryReader { contentGeometry in
                            Color.clear
                                .onAppear {
                                    scrollViewContentHeight = contentGeometry.size.height
                                }
                                .onChange(of: contentGeometry.size.height) { newHeight in
                                    scrollViewContentHeight = newHeight
                                }
                        }
                        .frame(height: 0)
                        
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
                                .background(.currentTabBg.opacity(
                                    id == calculateTabToSwitchIndex(appState.indexOfTabToSwitchTo)
                                    ? colorScheme == .dark ? 0.15 : 0.10 : 0))
                                .id(id)
                                .contentShape(Rectangle())
                                .cornerRadius(6)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding(4)
                                .onTapGesture {
                                    appState.indexOfTabToSwitchTo = id
                                    openSafariAndAskToSwitchTabs()
                                }
                                .background(
                                    GeometryReader { itemGeometry in
                                        Color.clear
                                            .onAppear {
                                                let frame = itemGeometry.frame(in: .named("scrollView"))
                                                itemPositions[id] = frame
                                            }
                                            .onChange(of: itemGeometry.frame(in: .named("scrollView"))) { newFrame in
                                                itemPositions[id] = newFrame
                                            }
                                    }
                                )
                            }
                        }
                        .padding(.top, 5)
                        .frame(minWidth: 800)
                    }
                    .coordinateSpace(name: "scrollView")
                    .onAppear {
                        scrollViewHeight = scrollViewGeometry.size.height
                    }
                    .onChange(of: scrollViewGeometry.size.height) { newHeight in
                        scrollViewHeight = newHeight
                    }
                    .background(
                        GeometryReader { scrollGeo in
                            let offset = scrollGeo.frame(in: .named("scrollView")).minY
                            return Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                        }
                    )
                    .onChange(of: appState.indexOfTabToSwitchTo) { newIndex in
                        let selectedIndex = calculateTabToSwitchIndex(newIndex)
                        
                        if let selectedItemFrame = itemPositions[selectedIndex] {
                            let isItemVisible = isItemFullyVisible(selectedItemFrame)
                            
                            if !isItemVisible {
                                withAnimation {
                                    let scrollAnchor = determineScrollAnchor(for: selectedItemFrame)
                                    if scrollAnchor != .center {
                                        proxy.scrollTo(selectedIndex, anchor: scrollAnchor)
                                    }
                                }
                            }
                        } else {
                            withAnimation {
                                proxy.scrollTo(selectedIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            if lastScrollPosition != offset {
                let topEdgeReached = offset >= 0
                let bottomEdgeReached = (scrollViewContentHeight - scrollViewHeight - abs(offset)) <= 20
                
                isUserNearEdge = topEdgeReached || bottomEdgeReached
                lastScrollPosition = offset
            }
        }
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            setUp()
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
    
    private func isItemFullyVisible(_ itemFrame: CGRect) -> Bool {
        return itemFrame.minY >= 0 && itemFrame.maxY <= scrollViewHeight
    }
    
    private func determineScrollAnchor(for itemFrame: CGRect) -> UnitPoint {
        if isUserNearEdge {
            if lastScrollPosition >= 0 {
                return .top
            } else if (scrollViewContentHeight - scrollViewHeight - abs(lastScrollPosition)) <= 20 {
                return .bottom
            }
        }
        
        if itemFrame.minY < 0 {
            return .top
        } else if itemFrame.maxY > scrollViewHeight {
            return .bottom
        }
        
        return .center
    }

    func setupInAppKeyListener() {
        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
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
        } else {
            print("Safari is not installed or not found.")
        }
    }

    func handleNavigationKeyPresses(event: NSEvent) {
        guard event.modifierFlags.contains(.option) else { return }
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
