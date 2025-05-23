import SwiftUI
import KeyboardShortcuts
import InputMethodKit

let tabsPanelFadeOutAnimationDuration: Double = 0.25

Store.userDefaults.register(
    defaults: [
        Store.isTabsSwitcherNeededToStayOpenStoreKey: Store.isTabsSwitcherNeededToStayOpenDefaultvalue
    ]
)

let appState = AppState()
let delegate = AppDelegate(appState: appState)
var pendingDispatchWorkItem: DispatchWorkItem?

func putIntoBackground() {
    greetingWindow?.orderOut(nil)
    settingsWindow?.orderOut(nil)
    aboutPanel?.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    
    guard Store.addStatusBarItemWhenAppMovesInBackground else { return }
    statusBarItem?.isVisible = true
}

NotificationCenter.default.addObserver(
    forName: NSWindow.didBecomeMainNotification,
    object: settingsWindow,
    queue: .main
) { notification in
    settingsWindow?.makeFirstResponder(settingsSidebarTableView)
}

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil,
    queue: .main
) { notification in
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
        return
    }
    if app.bundleIdentifier == "com.apple.Safari" {
        KeyboardShortcuts.isEnabled = true
    }
    else {
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            /// https://github.com/kopyl/safari-tab-switcher/issues/5
            return
        }
        hideTabsPanel()
        KeyboardShortcuts.isEnabled = false
    }
}

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didTerminateApplicationNotification,
    object: nil,
    queue: .main
) { notification in
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
        return
    }
    guard app.bundleIdentifier == "com.apple.Safari" else { return }
    /// App Review support does not want the app to run background processes when user quits Safari
    
    guard Store.moveAppOutOfBackgroundWhenSafariCloses else { return }

    let previousActivationPolicy = NSApp.activationPolicy()
    NSApp.setActivationPolicy(.regular)
    if previousActivationPolicy != .regular {    
        greetingWindow?.orderBack(nil)
        statusBarItem?.isVisible = false
    }
}

class TabsPanelVisibilityObserver: NSObject {
    private var panel: NSPanel
    private var observation: NSKeyValueObservation?

    init(panel: NSPanel) {
        self.panel = panel
        super.init()
        observation = panel.observe(\.isVisible, options: [.new]) { _, change in
            if let isVisible = change.newValue {
                KeyboardShortcuts.isEnabled = !isVisible
            }
        }
    }

    deinit {
        observation?.invalidate()
    }
}

extension KeyboardShortcuts.Name {
    static let openTabsList = Self("openTabsList", default: .init(.tab, modifiers: [.option]))
}

KeyboardShortcuts.onKeyDown(for: .openTabsList) {
    handleHotKeyPress()
}

func isUserHoldingShortcutModifiers(event: NSEvent? = nil) -> Bool {
    guard let shortcut = KeyboardShortcuts.Name.openTabsList.shortcut else { return false }
    let modifiersToCheck = event?.modifierFlags ?? NSEvent.modifierFlags
    return modifiersToCheck.contains(shortcut.modifiers)
}

func setIndexOfTabToSwitchToForEmptyTexField() {
    if appState.sortTabsBy == .lastSeen {
        if appState.openTabsRenderedCount == 1 {
            appState.indexOfTabToSwitchTo = 0
        }
        else {
            appState.indexOfTabToSwitchTo = 1
        }
    }
    else {
        appState.indexOfTabToSwitchTo = 0
    }
}

func handleHotKeyPress() {
    guard NSWorkspace.shared.frontmostApplication?.localizedName == "Safari" else {
        return
    }
    guard let tabs = Store.windows.windows.last?.tabs else { return }
    
    showTabsPanel()
    
    appState.savedOpenTabs = tabs.tabs
    appState.savedClosedTabs = Store.VisitedPagesHistory.loadAll()
    appState.searchQuery = ""
    prepareTabsForRender()
    setIndexOfTabToSwitchToForEmptyTexField()
    appState.currentInputSourceName = getCurrentInputSourceName()
    appState.isTabsPanelOpen = true
    
    (tabsPanel?.contentViewController as? TabHistoryView)?.updateTabsHeaderViews()
    (tabsPanel?.contentViewController as? TabHistoryView)?.renderTabs()
    (tabsPanel?.contentViewController as? TabHistoryView)?.updateSearchFieldPlaceholderText()
}

var greetingWindow: NSWindow?
var tabsPanel: NSPanel?
var settingsWindow: NSWindow?
var aboutPanel: NSPanel?
var statusBarItem: NSStatusItem?

/// for some reason it's required to keep a referece to SettingsWindowController
/// for shifting window buttons to works (close, minimize & expand)
var settingsWindowController: SettingsWindowController?

var settingsWindowTitle = SettingsTitleView()
let settingsSidebarTableView = NSTableView()

class AppState: ObservableObject {
    @Published var isShortcutRecorderNeedsToBeFocused = false
    
    var searchQuery = ""
    
    var savedOpenTabs = Tabs().tabs
    var savedClosedTabs = Tabs().tabs
    
    var isTabsSwitcherNeededToStayOpen = Store.isTabsSwitcherNeededToStayOpen
    var isTabsPanelOpen = false
    var sortTabsBy = Store.sortTabsBy
    var columnOrder = Store.columnOrder
    var currentInputSourceName = getCurrentInputSourceName()
    var modifierKeysString = KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers.symbolRepresentation
    var userSelectedAccentColor = Store.userSelectedAccentColor
    var tabsWithOpenSwipeViews: [TabItemView] = []
    var addStatusBarItemWhenAppMovesInBackground = Store.addStatusBarItemWhenAppMovesInBackground

    var openTabsRenderedCount = 0
    var closedTabsRenderedCount = 0

    var renderedTabs: [Tab] = []
    
    private var _indexOfTabToSwitchTo = -1
    var indexOfTabToSwitchTo: Int {
        get { _indexOfTabToSwitchTo }
        set {
            if renderedTabs.isEmpty {
                _indexOfTabToSwitchTo = 0
            } else {
                _indexOfTabToSwitchTo = pythonTrueModulo(newValue, renderedTabs.count)
            }
        }
    }
}

class Window: NSWindow {
    init(view: some View, styleMask: NSWindow.StyleMask = [.titled, .closable]) {
        super.init(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.contentViewController = NSHostingController(rootView: view)
        
        /// NSWindowController wrapping fixes app breaking on window close -> app reopen
        let _ = NSWindowController(window: self)
    }
}

/// A custom class with canBecomeKey overridden to true is required for cursor in the text field to blink
///
/// Either this or .titled style mask is needed
class Panel: NSPanel {
    init(view: some View, styleMask: NSWindow.StyleMask = [.nonactivatingPanel]) {
        super.init(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.contentViewController = NSHostingController(rootView: view)
    }
    
    init(view: some NSViewController, styleMask: NSWindow.StyleMask = [.nonactivatingPanel]) {
        super.init(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.contentViewController = view
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

func createGreetingWindow() {
    greetingWindow = Window(view: GreetingView())
    
    greetingWindow?.backgroundColor = .greetingBg
    greetingWindow?.title = Copy.Onboarding.title
    greetingWindow?.setContentSize(NSSize(width: 759, height: 781))
    greetingWindow?.center()
}

func showGreetingWindow() {
    greetingWindow?.makeKeyAndOrderFront(nil)
    NSApp.setActivationPolicy(.regular)
}

func createTabsPanel() {
    tabsPanel = Panel(
        view: TabHistoryView()
    )
    
    tabsPanel?.backgroundColor = .clear
    tabsPanel?.center()
    tabsPanel?.identifier = tabsPanelID
    
    tabsPanel?.hasShadow = false
}

func showTabsPanel() {
    /// .fullScreenPrimary collectionBehavior and .floating level are both required tabs window to be displayed in a Safari's full screen mode.
    /// collectionBehavior needs to be set on every time this function calls for the tabs window to be displayed in a Safari's full screen mode.
    /// On a fresh macOS 13.0 the app prefectly works with a full-screen Safari without .canJoinAllSpaces and moving
    /// .floating level setting from window init to window display, but Sava had issues without them
    /// Maybe only ony thing helped – either moving .floating level setting here or addding .canJoinAllSpaces. to the collectionBehavior
    /// For me on macOS 15.x everything works with onlyt setting fullScreenPrimary. Sava haven't tried it yet
    tabsPanel?.level = .floating
    tabsPanel?.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    
    tabsPanel?.makeKeyAndOrderFront(nil)
    
    if !Store.isTabsSwitcherNeededToStayOpen && appState.sortTabsBy == .lastSeen {
        tabsPanel?.contentView?.alphaValue = 0
        pendingDispatchWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            tabsPanel?.contentView?.alphaValue = 1
            KeyboardShortcuts.isEnabled = false
        }
        pendingDispatchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}

func hideTabsPanel(withoutAnimation: Bool = false) {
    let animationDuration = withoutAnimation ? 0 : tabsPanelFadeOutAnimationDuration
    
    NSApp.deactivate()
    
    appState.isTabsPanelOpen = false
    
    NSAnimationContext.runAnimationGroup({ context in
        context.duration = animationDuration
        tabsPanel?.animator().contentView?.alphaValue = 0
        
        KeyboardShortcuts.isEnabled = true
        
        pendingDispatchWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            tabsPanel?.orderOut(nil)
            tabsPanel?.animator().contentView?.alphaValue = 1
            
            /// https://github.com/kopyl/safari-tab-switcher/issues/5
            if NSApp.isActive {
                NSApp.hide(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration, execute: workItem)
        pendingDispatchWorkItem = workItem
    })
}

func showSettingsWindow(withTitle: String = "Settings") {
    if let settingsWindow {
        settingsWindowTitle.stringValue = withTitle
        settingsWindow.makeKeyAndOrderFront(nil)
        addPaddingToWindowButtons(leading: 10, top: 10)
        return
        
    }
    
    settingsWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: WindowConfig.width, height: WindowConfig.height),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered, defer: false
    )
    settingsWindow?.center()
    settingsWindow?.contentViewController = SplitViewController()
    settingsWindow?.titlebarAppearsTransparent = true
    
    settingsWindowTitle.stringValue = withTitle
    
    /// hack to increase draggable titlebar area
    settingsWindow?.addTitlebarAccessoryViewController(NSTitlebarAccessoryViewController())
    
    settingsWindowController = SettingsWindowController(window: settingsWindow)
    addPaddingToWindowButtons(leading: 10, top: 10)
    
    settingsWindow?.makeKeyAndOrderFront(nil)
}

func showAboutPanel() {
    if let aboutPanel {
        aboutPanel.makeKeyAndOrderFront(nil)
        return
    }
    
    aboutPanel = Panel(
        view: AboutView(),
        styleMask: [.titled, .closable]
    )
    
    aboutPanel?.setContentSize(NSSize(width: 444, height: 177))
    aboutPanel?.center()
    aboutPanel?.makeKeyAndOrderFront(nil)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState
    var panelObserver: TabsPanelVisibilityObserver?
    var isStatusBarItemVisibleMenuItem = NSMenuItem(
        title: "Show status bar item",
        action: nil,
        keyEquivalent: ""
    )
    
    init(
        appState: AppState
    ) {
        self.appState = appState
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createGreetingWindow()
        showGreetingWindow()
        createTabsPanel()
        panelObserver = TabsPanelVisibilityObserver(panel: tabsPanel!)
        addStatusBarItem()
        
        #if DEBUG
        setupLoggingFromSafariExtension()
        #endif
    }
    
    private func addStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let button = statusBarItem?.button else { return }
        button.image = NSImage(named: "status-bar-icon")

        let menu = NSMenu()
       
        isStatusBarItemVisibleMenuItem.action = #selector(hideStatusBarItem)
        isStatusBarItemVisibleMenuItem.state = .on
        isStatusBarItemVisibleMenuItem.target = self
        
        menu.addItem(isStatusBarItemVisibleMenuItem)
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(Application.openSettingsWindowWithTabFinderTitle), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())

        let supportMenuItem = NSMenuItem(title: "Support", action: nil, keyEquivalent: "")
        menu.addItem(supportMenuItem)
        let supportSubmenu = NSMenu()
        supportMenuItem.submenu = supportSubmenu
        Application.addSupportItems(to: supportSubmenu)
        
        Application.addLinkMenuItem(to: menu, title: "Contribute on GitHub", webURL: "https://github.com/kopyl/safari-tab-switcher")
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem?.menu = menu
        statusBarItem?.isVisible = false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        tabsPanel?.orderOut(nil)
        greetingWindow?.makeKeyAndOrderFront(nil)
        statusBarItem?.isVisible = false
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @objc func hideStatusBarItem() {
        statusBarItem?.isVisible = false
        appState.addStatusBarItemWhenAppMovesInBackground = false
        Store.addStatusBarItemWhenAppMovesInBackground = false
    }
}

class Application: NSApplication {
    
    private func createMenu() {
        self.mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        self.mainMenu?.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(title: "About \(ProcessInfo.processInfo.processName)",
          action: #selector(openAboutPanel),
          keyEquivalent: "i")
        )
        appMenu.addItem(NSMenuItem(title: "Settings",
           action: #selector(openSettingsWindow),
           keyEquivalent: ",")
        )
        
        
        appMenu.addItem(.separator())
        Application.addLinkMenuItem(to: appMenu, title: "Contribute on GitHub", webURL: "https://github.com/kopyl/safari-tab-switcher")
        appMenu.addItem(.separator())
        
        appMenu.addItem(NSMenuItem(title: "Quit \(ProcessInfo.processInfo.processName)",
           action: #selector(terminate(_:)),
           keyEquivalent: "q")
        )

        let windowMenuItem = NSMenuItem()
        self.mainMenu?.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: "Close Window",
          action: #selector(NSWindow.performClose(_:)),
          keyEquivalent: "w")
        )

        windowMenu.addItem(.separator())
        let openGreetingWindowMenuItem = NSMenuItem(
            title: "Welcome to \(appName)",
            action: #selector(openGreetingWindow),
            keyEquivalent: "1"
        )
        openGreetingWindowMenuItem.keyEquivalentModifierMask = [.command, .option]
        windowMenu.addItem(openGreetingWindowMenuItem)
        
        let helpMenuItem = NSMenuItem()
        self.mainMenu?.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Support")
        helpMenuItem.submenu = helpMenu

        Application.addSupportItems(to: helpMenu)
    }
    
    public static func addSupportItems(to menu: NSMenu) {
        Application.addLinkMenuItem(to: menu, title: "Email", webURL: "mailto:kopyloleh@gmail.com?subject=Tab%20Finder%20Support&body=Hello,%20I'm%20writing%20regarding%20Tab%20Finder...")
        Application.addLinkMenuItem(to: menu, title: "Telegram", webURL: "https://t.me/kopyl", appURL: "tg://resolve?domain=kopyl")
        Application.addLinkMenuItem(to: menu, title: "Discord DM", webURL: "https://discordapp.com/users/346770476992954369", appURL: "discord://discordapp.com/users/346770476992954369")
        Application.addLinkMenuItem(to: menu, title: "Discord Community", webURL: "https://discord.gg/PSAcv7QfRR")
        Application.addLinkMenuItem(to: menu, title: "iMessage", appURL: "sms:+380507308141")
        Application.addLinkMenuItem(to: menu, title: "+380507308141", appURL: "facetime:+380507308141")
        Application.addLinkMenuItem(to: menu, title: "x.com", webURL: "https://x.com/TabFinderMac")
        Application.addLinkMenuItem(to: menu, title: "GitHub", webURL: "https://github.com/kopyl/safari-tab-switcher/issues/new")
    }
    
    public static func addLinkMenuItem(to menu: NSMenu, title: String, webURL: String? = nil, appURL: String? = nil) {
            let menuItem = NSMenuItem(title: title, action: #selector(openSupportLink(_:)), keyEquivalent: "")
            menuItem.representedObject = [ "webAppURL": webURL as Any, "appURL": appURL as Any ]
            menu.addItem(menuItem)
        }

        @objc private func openSupportLink(_ sender: NSMenuItem) {
            guard let info = sender.representedObject as? [String: Any] else { return }

            if let appURLString = info["appURL"] as? String, let appURL = URL(string: appURLString),
               NSWorkspace.shared.urlForApplication(toOpen: appURL) != nil {
                NSWorkspace.shared.open(appURL)
            } else {
                guard let webURLString = info["webAppURL"] as? String else { return }
                guard let webURL = URL(string: webURLString) else { return }
                NSWorkspace.shared.open(webURL)
            }
        }
    
    @objc func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        /// Making window key is needed to prevent shortcut recorder become focused
        settingsWindow?.becomeKey()
        
        showSettingsWindow()
    }
    
    @objc func openSettingsWindowWithTabFinderTitle() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.becomeKey()
        showSettingsWindow(withTitle: "\(appName) Settings")
    }

    @objc func openAboutPanel() {
        showAboutPanel()
    }
    
    @objc func openGreetingWindow() {
        showGreetingWindow()
    }
    
    @objc func openAppStoreLink() {
        if let url = URL(string: appStoreURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    override init() {
        super.init()
        createMenu()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else {
            return super.sendEvent(event)
        }

        guard NSApp.keyWindow?.identifier == tabsPanelID else {
            return super.sendEvent(event)
        }

        guard isUserHoldingShortcutModifiers(event: event) else {
            return super.sendEvent(event)
        }
        
        /// space is pressed
        if event.keyCode == 49 && appState.searchQuery == "" {
            selectPreviousInputSource()
            return
        }

        let newFlags = appState.isTabsSwitcherNeededToStayOpen
            ? event.modifierFlags
            : event.modifierFlags.subtracting(KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers ?? [])

        if NavigationKeys(rawValue: event.keyCode) != nil {
            return super.sendEvent(event)
        }

        guard let charactersIgnoringModifiers = event.charactersIgnoringModifiers,
              let characters = event.characters else {
            return super.sendEvent(event)
        }

        if let newEvent = NSEvent.keyEvent(
            with: event.type,
            location: event.locationInWindow,
            modifierFlags: newFlags,
            timestamp: event.timestamp,
            windowNumber: event.windowNumber,
            context: nil,
            characters: appState.isTabsSwitcherNeededToStayOpen ? characters : charactersIgnoringModifiers,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: event.isARepeat,
            keyCode: event.keyCode
        ) {
            return super.sendEvent(newEvent)
        }

        super.sendEvent(event)
    }
}

let app = Application.shared
app.delegate = delegate

app.run()
