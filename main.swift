import SwiftUI
import HotKey

let appState = AppState()
let hotKey = HotKey(key: .tab, modifiers: [.option], keyDownHandler: handleHotKeyPress)
let delegate = AppDelegate(appState: appState)
var pendingDispatchWorkItem: DispatchWorkItem?

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
            hotKey: hotKey,
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
    
    settingsWindow = Window(view: SettingsView())
    
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
                    hotKey.isPaused = false
                } else {
                    hotKey.isPaused = true
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
        if event.type == .keyDown {
            if event.modifierFlags.contains(.option) {
                
                var newFlags: NSEvent.ModifierFlags
                if appState.isTabsSwitcherNeededToStayOpen {
                    newFlags = event.modifierFlags
                }
                else {
                    newFlags = event.modifierFlags.subtracting(.option)
                }
                
                if NavigationKeys(rawValue: event.keyCode) != nil {
                    super.sendEvent(event)
                    return
                }
                
                guard let charactersIgnoringModifiers = event.charactersIgnoringModifiers else {
                    super.sendEvent(event)
                    return
                }
                
                guard let characters = event.characters else {
                    super.sendEvent(event)
                    return
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
                    super.sendEvent(newEvent)
                    return
                }
            }
        }
        super.sendEvent(event)
    }
}

let app = Application.shared
app.delegate = delegate

app.run()
