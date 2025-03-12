import SwiftUI
import KeyboardShortcuts

let appState = AppState()
let delegate = AppDelegate(appState: appState)
var pendingDispatchWorkItem: DispatchWorkItem?

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
    startUsingTabFinder()
    showTabsWindow()
}

var greetingWindow: NSWindow?
var tabsWindow: NSWindow?
var settingsWindow: NSWindow?

class AppState: ObservableObject {
    @Published var searchQuery = ""
    @Published var tabIDsWithTitleAndHost = Tabs()
    @Published var filteredTabs: [TabForSearch] = []
    @Published var isTabsSwitcherNeededToStayOpen = false
    @Published var isShortcutRecorderNeedsToBeFocused: Bool = false
    
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

/// A custom class with canBecomeKey overridden to true is required for cursor in the text field to blink
///
/// Either this or .titled style mask is needed
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
    
    override var canBecomeKey: Bool {
        true
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

func createTabsWindow() {
    tabsWindow = Window(
        view: TabHistoryView(
            appState: appState
        ),
        styleMask: []
    )
    
    tabsWindow?.backgroundColor = .clear
    tabsWindow?.contentView?.layer?.cornerRadius = 8
    
    /// without this corner radius is not set on macOS 13.0. On 15.0 it works without masksToBounds
    tabsWindow?.contentView?.layer?.masksToBounds = true
    
    tabsWindow?.setContentSize(NSSize(width: 800, height: 500))
    tabsWindow?.center()
    tabsWindow?.hidesOnDeactivate = true
    tabsWindow?.identifier = tabsWindowID
}

func showTabsWindow() {
    /// .fullScreenPrimary collectionBehavior and .floating level are both required tabs window to be displayed in a Safari's full screen mode.
    /// collectionBehavior needs to be set on every time this function calls for the tabs window to be displayed in a Safari's full screen mode.
    /// On a fresh macOS 13.0 the app prefectly works with a full-screen Safari without .canJoinAllSpaces and moving
    /// .floating level setting from window init to window display, but Sava had issues without them
    /// Maybe only ony thing helped – either moving .floating level setting here or addding .canJoinAllSpaces. to the collectionBehavior
    /// For me on macOS 15.x everything works with onlyt setting fullScreenPrimary. Sava haven't tried it yet
    tabsWindow?.level = .floating
    tabsWindow?.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
    
    tabsWindow?.makeKeyAndOrderFront(nil)
    
    if !Store.isTabsSwitcherNeededToStayOpen {
        tabsWindow?.contentView?.alphaValue = 0
        pendingDispatchWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            tabsWindow?.contentView?.alphaValue = 1
        }
        pendingDispatchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    DispatchQueue.main.async {
        /// Activating the window with a DispatchQueue gets rid of the blinking
        /// Reference commit SHA: 680c206401d25960b9eb5a7f6fd900f439fd0af3
        NSApp.activate(ignoringOtherApps: true)
    }
}

func hideTabsWindow() {
    tabsWindow?.orderOut(nil)
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
    private var activeAppObserver: Any?
    
    init(
        appState: AppState
    ) {
        self.appState = appState
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createGreetingWindow()
        showGreetingWindow()
        createTabsWindow()
        setupAppSwitchingObserver()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showGreetingWindow()
        hideTabsWindow()
        return true
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
                    KeyboardShortcuts.isEnabled = true
                } else {
                    KeyboardShortcuts.isEnabled = false
                }
            }
        }
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

        guard NSApp.keyWindow?.identifier == tabsWindowID else {
            return super.sendEvent(event)
        }

        guard isUserHoldingShortcutModifiers(event: event) else {
            return super.sendEvent(event)
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
