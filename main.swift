import SwiftUI
import KeyboardShortcuts

let tabsPanelFadeOutAnimationDuration = 0.25

let appState = AppState()
let delegate = AppDelegate(appState: appState)
var pendingDispatchWorkItem: DispatchWorkItem?

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

NotificationCenter.default.addObserver(
    forName: NSWindow.didResignKeyNotification,
    object: tabsPanel,
    queue: .main
) { notification in
    guard notification.object as? NSObject == tabsPanel else { return }
    guard [1, 2].contains(NSEvent.pressedMouseButtons) else { return }
    hideTabsPanel(withoutAnimation: true)
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

func handleHotKeyPress() {
    guard NSWorkspace.shared.frontmostApplication?.localizedName == "Safari" else {
        return
    }
    guard let tabs = Store.windows.windows.last?.tabs else { return }
    appState.tabIDsWithTitleAndHost = tabs
    appState.searchQuery = ""
    filterTabs()
    appState.indexOfTabToSwitchTo = 1
    NSApp.setActivationPolicy(.accessory)
    appState.isTabsPanelOpen = true
    showTabsPanel()
}

var greetingWindow: NSWindow?
var tabsPanel: NSPanel?
var settingsWindow: NSWindow?

class AppState: ObservableObject {
    @Published var searchQuery = ""
    @Published var tabIDsWithTitleAndHost = Tabs()
    @Published var filteredTabs: [TabForSearch] = []
    @Published var isTabsSwitcherNeededToStayOpen = false
    @Published var isShortcutRecorderNeedsToBeFocused: Bool = false
    @Published var isTabsPanelOpen: Bool = false
    
    @Published private var _indexOfTabToSwitchTo = -1
    var indexOfTabToSwitchTo: Int {
        get { _indexOfTabToSwitchTo }
        set {
            if filteredTabs.isEmpty {
                _indexOfTabToSwitchTo = 0
            } else {
                _indexOfTabToSwitchTo = pythonTrueModulo(newValue, filteredTabs.count)
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
    
    override var canBecomeKey: Bool {
        return true
    }
}

func createGreetingWindow() {
    greetingWindow = Window(view: GreetingView(
        appState: appState
    ))
    
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
        view: TabHistoryView(
            appState: appState
        )
    )
    
    tabsPanel?.backgroundColor = .clear
    tabsPanel?.contentView?.layer?.cornerRadius = 8
    
    /// without this corner radius is not set on macOS 13.0. On 15.0 it works without masksToBounds
    tabsPanel?.contentView?.layer?.masksToBounds = true
    
    tabsPanel?.setContentSize(NSSize(width: 800, height: 500))
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
    tabsPanel?.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
    
    tabsPanel?.makeKeyAndOrderFront(nil)
    
    if !Store.isTabsSwitcherNeededToStayOpen {
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

func showSettingsWindow() {
    if let settingsWindow {
        settingsWindow.makeKeyAndOrderFront(nil)
        return
    }
    
    settingsWindow = Window(view: SettingsView(appState: appState))
    
    settingsWindow?.title = "Settings"
    settingsWindow?.setContentSize(NSSize(width: 562, height: 155))
    settingsWindow?.center()
    settingsWindow?.makeKeyAndOrderFront(nil)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState
    var panelObserver: TabsPanelVisibilityObserver?
    
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
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showGreetingWindow()
        tabsPanel?.resignKey()
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

class Application: NSApplication {
    private func createMenu() {
        self.mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        self.mainMenu?.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "Quit \(ProcessInfo.processInfo.processName)",
           action: #selector(terminate(_:)),
           keyEquivalent: "q")
        )
        appMenu.addItem(NSMenuItem(title: "Settings",
           action: #selector(openSettingsWindow),
           keyEquivalent: ",")
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
            title: "Welcome to Tab Finder",
            action: #selector(openGreetingWindow),
            keyEquivalent: "1"
        )
        openGreetingWindowMenuItem.keyEquivalentModifierMask = [.command, .option]
        windowMenu.addItem(openGreetingWindowMenuItem)
        
        let helpMenuItem = NSMenuItem()
        self.mainMenu?.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Support")
        helpMenuItem.submenu = helpMenu

        addSupportMenuItem(to: helpMenu, title: "Email", webAppURL: "mailto:kopyloleh@gmail.com?subject=Tab%20Finder%20Support&body=Hello,%20I'm%20writing%20regarding%20Tab%20Finder...")
        addSupportMenuItem(to: helpMenu, title: "Telegram", webAppURL: "https://t.me/kopyl", appURL: "tg://resolve?domain=kopyl")
        addSupportMenuItem(to: helpMenu, title: "Discord", webAppURL: "https://discordapp.com/users/346770476992954369", appURL: "discord://discordapp.com/users/346770476992954369")
        addSupportMenuItem(to: helpMenu, title: "iMessage", appURL: "sms:+380507308141")
        addSupportMenuItem(to: helpMenu, title: "+380507308141", appURL: "facetime:+380507308141")
    }
    
    private func addSupportMenuItem(to menu: NSMenu, title: String, webAppURL: String? = nil, appURL: String? = nil) {
            let menuItem = NSMenuItem(title: title, action: #selector(openSupportLink(_:)), keyEquivalent: "")
            menuItem.representedObject = [ "webAppURL": webAppURL as Any, "appURL": appURL as Any ]
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
        showSettingsWindow()
    }
    
    @objc func openGreetingWindow() {
        showGreetingWindow()
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
