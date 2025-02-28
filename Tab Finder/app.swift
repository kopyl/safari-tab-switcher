import SwiftUI
import SafariServices.SFSafariExtensionManager
import HotKey

var greetingWindow: NSWindow?
var tabsWindow: NSWindow?

class AppState: ObservableObject {
    @Published var isUserOnboarded: Bool = false
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

/// A custom class with canBecomeKey overridden to true is required for cursor in the text field to blink
///
/// Either this or .titled style mask is needed
class Window: NSWindow {
    init(isRegualar: Bool = true) {
        super.init(
            contentRect: .zero,
            styleMask: isRegualar ? [.titled, .closable] : [],
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
    }
    
    override var canBecomeKey: Bool {
        true
    }
}

func showGreetingWindow(appState: AppState? = nil) {
    guard let appState else { return }
    
    if let greetingWindow {
        appState.isUserOnboarded = false
        greetingWindow.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        return
    }
    
    let greetingView = NSHostingController(rootView: GreetingView(appState: appState))
    
    greetingWindow = Window()
    greetingWindow?.contentViewController = greetingView
    
    greetingWindow?.backgroundColor = .greetingBg
    greetingWindow?.title = Copy.Onboarding.title
    greetingWindow?.setContentSize(NSSize(width: 759, height: 781))
    greetingWindow?.center()
    greetingWindow?.makeKeyAndOrderFront(nil)
}

func hideMainWindow() {
    tabsWindow?.orderOut(nil)
}

func showMainWindow(showOrHideTabsHistoryWindowHotKey: HotKey, appState: AppState) {
    if let tabsWindow {
        tabsWindow.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }

    let tabsView = NSHostingController(
        rootView: TabHistoryView(
            showOrHideTabsHistoryWindowHotKey: showOrHideTabsHistoryWindowHotKey,
            appState: appState
        )
    )
    
    tabsWindow = Window(isRegualar: false)
    
    tabsWindow?.contentViewController = tabsView
    tabsWindow?.backgroundColor = .clear
    tabsWindow?.contentView?.layer?.cornerRadius = 8
    tabsWindow?.setContentSize(NSSize(width: 800, height: 500))
    tabsWindow?.center()
    tabsWindow?.hidesOnDeactivate = true
}

struct TabHistoryView: View {
    var showOrHideTabsHistoryWindowHotKey: HotKey
    
    @State private var indexOfTabToSwitchTo: Int = 1
    @State private var tabIDsWithTitleAndHost = Tabs()
    @State private var keyMonitors: [Any] = []
    @State private var searchQuery: String = ""
    @State private var searchCursorPosition: Int = 0
    @State private var filteredTabs: [TabForSearch] = []
    @ObservedObject var appState: AppState
    @Environment(\.scenePhase) var scenePhase
    
    func setUp() {
        showOrHideTabsHistoryWindowHotKey.keyDownHandler = handleHotKeyPress
        setupInAppKeyListener()
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
            .padding(.top, 16)
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
            setUp()
            showGreetingWindow(appState: appState)
        }
        .task {
            hideMainWindow()
        }
        .onDisappear {
            removeInAppKeyListener()
        }
        .onChange(of: scenePhase) { phase in
            guard appState.isUserOnboarded == true else { return }
            guard !NSEvent.modifierFlags.contains(.option) else { return }
            openSafariAndAskToSwitchTabs()
        }
    }
    
    func isCommandQPressed(event: NSEvent) -> Bool {
        if NSEvent.modifierFlags.contains(.command) && event.keyCode == 12 {
            return true
        }
        return false
    }
    
    func isCommandWPressed(event: NSEvent) -> Bool {
        if NSEvent.modifierFlags.contains(.command) && event.keyCode == 13 {
            return true
        }
        return false
    }

    func setupInAppKeyListener() {
        let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if isCommandWPressed(event: event) {
                return event
            }
            
            if NavigationKeys(rawValue: event.keyCode) != nil {
                handleNavigationKeyPresses(event: event)
                return nil
            }
            
            if isCommandQPressed(event: event) {
                NSApplication.shared.terminate(nil)
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
        guard appState.isUserOnboarded else { return }
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
            if searchQuery.count + searchCursorPosition > 0 {
                let indexToRemove = searchQuery.index(searchQuery.endIndex, offsetBy: searchCursorPosition-1)
                searchQuery.remove(at: indexToRemove)
            }
            filterTabs()
            
        default:
            let charToInsert = event.charactersIgnoringModifiers ?? ""
            let insertionIndex = searchQuery.index(searchQuery.endIndex, offsetBy: searchCursorPosition)
            searchQuery.insert(contentsOf: charToInsert, at: insertionIndex)
            filterTabs()
        }
        return nil
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
            hideTabSwitcherUI()
        }
    }

    func calculateTabToSwitchIndex(_ indexOfTabToSwitchTo: Int) -> Int {
        if filteredTabs.isEmpty {
            return 0
        }
        return pythonTrueModulo(indexOfTabToSwitchTo, filteredTabs.count)
    }

    private func handleHotKeyPress() {
        guard NSWorkspace.shared.frontmostApplication?.localizedName == "Safari" else {
            return
        }
        
        guard let tabs = Store.windows.windows.last?.tabs else { return }
        tabIDsWithTitleAndHost = tabs
        searchQuery = ""
        searchCursorPosition = 0
        filterTabs()
        indexOfTabToSwitchTo = 1
        startUsingTabFinder()
        appState.isUserOnboarded = true
        showMainWindow(showOrHideTabsHistoryWindowHotKey: showOrHideTabsHistoryWindowHotKey, appState: appState)
    }

    private func openSafariAndAskToSwitchTabs() {
        hideTabSwitcherUI()
        openSafari()
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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var showOrHideTabsHistoryWindowHotKey: HotKey?
    var appState: AppState?
    private var activeAppObserver: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let hotKey = showOrHideTabsHistoryWindowHotKey, let state = appState {
            showMainWindow(showOrHideTabsHistoryWindowHotKey: hotKey, appState: state)
        }
        
        setupAppSwitchingObserver()
        setUpNSWindowDelegate()
    }
    
    func setUpNSWindowDelegate() {
        greetingWindow?.delegate = self
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showGreetingWindow(appState: appState)
        hideMainWindow()
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
            for url in urls {
                if url.scheme == "tabfinder" {
                    showGreetingWindow(appState: appState)
                }
            }
        }
    
    func setupAppSwitchingObserver() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        
        activeAppObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            if let bundleIdentifier = app.bundleIdentifier {
                if bundleIdentifier == "com.apple.Safari" {
                    self.showOrHideTabsHistoryWindowHotKey?.isPaused = false
                } else {
                    self.showOrHideTabsHistoryWindowHotKey?.isPaused = true
                }
            }
        }
    }
}

@main
struct MySafariApp: App {
    let showOrHideTabsHistoryWindowHotKey = HotKey(key: .tab , modifiers: [.option])
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        appDelegate.showOrHideTabsHistoryWindowHotKey = showOrHideTabsHistoryWindowHotKey
        appDelegate.appState = AppState()
    }
    
    var body: some Scene {
        Settings {}
    }
}
