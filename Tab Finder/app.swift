import SwiftUI
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

struct GreetingView: View {
    func startUsingTabFinder() {
        guard let greetingWindow = NSApp.windows.first(where: {$0.title == Copy.Onboarding.title}) else {
            return
        }
        greetingWindow.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        Store.isUserOnboarded = true
    }
    
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
            Spacer()
            
            OnboardingButton {
                startUsingTabFinder()
            }
            .padding(.bottom, 41)
            .padding(.horizontal, 41)
        }
        .frame(width: 759, height: 781)
        .background(.greetingBg)
        .onDisappear {
            startUsingTabFinder()
        }
    }
}

var greetingWindow: NSWindow?

func showGreetingWindow(isOnboarded: Bool) {
    if isOnboarded == true {
        NSApp.setActivationPolicy(.accessory)
        return
    }
    
    let greetingView = NSHostingController(rootView: GreetingView())
    
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    
    window.titlebarAppearsTransparent = true
    
    window.backgroundColor = .greetingBg

    window.contentViewController = greetingView
    window.title = Copy.Onboarding.title
    window.center()
    window.makeKeyAndOrderFront(nil)
    
    greetingWindow = window
}

func hideMainWindow() {
    guard let mainWindow = NSApp.windows.first(where: {$0.title != Copy.Onboarding.title}) else {
        return
    }
    mainWindow.orderOut(nil)
}

func showMainWindow() {
    let isUserOnboarded = Store.isUserOnboarded
    if !isUserOnboarded {
        guard let greetingWindow = NSApp.windows.first(where: {$0.title == Copy.Onboarding.title}) else {
            return
        }
        
        greetingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }
    
    guard let mainWindow = NSApp.windows.first(where: {$0.title != Copy.Onboarding.title}) else {
        return
    }
    mainWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

struct TabHistoryView: View {
    @State private var indexOfTabToSwitchTo: Int = 1
    @State private var tabIDsWithTitleAndHost = Tabs()
    @State private var notificationObserver: NSObjectProtocol?
    @State private var keyMonitors: [Any] = []
    @State private var searchQuery: String = ""
    @State private var searchCursorPosition: Int = 0
    
    @State private var filteredTabs: [TabForSearch] = []
    
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage(Store.isUserOnboardedKey, store: Store.userDefaults) private var isUserOnboarded: Bool = false
    
    func setUp(isOnboarded: Bool) {
        if isOnboarded == true {
            setupDistributedNotificationListener()
            setupInAppKeyListener()
        }
    }
    
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
                    cursorPosition: $searchCursorPosition,
                    placeholder: "Search among ^[\(tabsCount) \("tab")](inflect: true)"
                )
            }
            .padding(.leading, 20)
            .padding(.top, -12)
            .padding(.trailing, 20)
            .padding(.bottom, 26)

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

                            HStack(alignment: .center) {
                                Text(pageHostFormatted)
                                .font(.system(size: 18))
                                .foregroundStyle(
                                    id == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? .white : .primary.opacity(0.9)
                                )
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                
                                Text(pageTitleFormatted)
                                .font(.system(size: 13))
                                .foregroundStyle(
                                    id == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? .white : Color.primary
                                )
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .opacity(0.65)
                            }
                                .lineLimit(1)
                                .padding(.top, 14).padding(.bottom, 14)
                                .padding(.leading, 18).padding(.trailing, 18)
                                .background(.blue.opacity(
                                    id == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? 1 : 0))
                                .id(id)
                                .contentShape(Rectangle())
                                .cornerRadius(6)
                            
                                .frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, maxWidth: .infinity)
                                .padding(4)
                            
                                .onTapGesture {
                                    indexOfTabToSwitchTo = id
                                    openSafariAndAskToSwitchTabs()
                                }
                        }
                    }
                    .padding(.top, 5)
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
            setUp(isOnboarded: isUserOnboarded)
            showGreetingWindow(isOnboarded: isUserOnboarded)
        }
        .onDisappear {
            removeDistributedNotificationListener()
            removeInAppKeyListener()
        }
        .task {
            hideMainWindow()
            hideAppControls()
        }
        .onChange(of: isUserOnboarded) { isOnboarded in
            setUp(isOnboarded: isOnboarded)
        }
        .onChange(of: scenePhase) { phase in
            guard isUserOnboarded == true else { return }
            guard !NSEvent.modifierFlags.contains(.option) else { return }
            openSafariAndAskToSwitchTabs()
        }
    }

    func hideAppControls() {
        guard let window = NSApp.windows.first(where: {$0.title != Copy.Onboarding.title}) else {
            return
        }
        
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.setContentSize(NSSize(width: 800, height: 500))
        window.center()
        
        let titlebarBlurView = VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)._makeNSView()
        let titlebarFrame = NSRect(x: 0, y: window.frame.height - 28, width: window.frame.width, height: 28)
        titlebarBlurView.frame = titlebarFrame
        titlebarBlurView.autoresizingMask = [.width, .minYMargin]
        window.contentView?.superview?.addSubview(titlebarBlurView, positioned: .below, relativeTo: window.contentView)
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
            if NavigationKeys(rawValue: event.keyCode) != nil {
                handleNavigationKeyPresses(event: event)
                return nil
            }
            return handleTypingKeyPresses(event: event)
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
    
    func handleTypingKeyPresses(event: NSEvent) -> NSEvent? {
        switch TypingKeys(rawValue: event.keyCode) {
        case .arrowLeft:
            searchCursorPosition = max(searchCursorPosition-1, -searchQuery.count)
        case .arrowRight:
            searchCursorPosition = min(searchCursorPosition+1, 0)

        case .backspace:
            guard !searchQuery.isEmpty else { return nil }
            searchQuery.removeLast()
            filterTabs()
        default:
            searchQuery.append(event.charactersIgnoringModifiers ?? "")
            filterTabs()
        }
        return nil
    }

    func handleNavigationKeyPresses(event: NSEvent) {
        guard event.modifierFlags.contains(.option) else { return }
        guard !tabIDsWithTitleAndHost.isEmpty else { return }
        guard let key = NavigationKeys(rawValue: event.keyCode) else { return }

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
        showMainWindow()
    }

    private func removeDistributedNotificationListener() {
            if let observer = notificationObserver {
                DistributedNotificationCenter.default().removeObserver(observer)
            }
        }

    private func setupDistributedNotificationListener() {
            notificationObserver = DistributedNotificationCenter.default().addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { notification in
                handleNotification(notification)
            }
        }

    private func handleNotification(_ notification: Notification) {
        guard let tabs = Store.windows.windows.last?.tabs else { return }
        tabIDsWithTitleAndHost = tabs
        searchQuery = ""
        searchCursorPosition = 0
        filterTabs()
        indexOfTabToSwitchTo = 1
        bringWindowToFront()
    }

    private func openSafariAndAskToSwitchTabs() {
        openSafariAndHideTabSwitcherUI()
        guard !filteredTabs.isEmpty else { return }
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
