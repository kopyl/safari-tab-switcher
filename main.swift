import SwiftUI
import HotKey

let appState = AppState()

var greetingWindow: NSWindow?
var tabsWindow: NSWindow?
var settingsWindow: NSWindow?

class AppState: ObservableObject {
    @Published var isUserOnboarded = false
    @Published var searchQuery = ""
    @Published var tabIDsWithTitleAndHost = Tabs()
    @Published var indexOfTabToSwitchTo = 1
    @Published var filteredTabs: [TabForSearch] = []
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

func renderGreetingWindow(andShow: Bool? = false) {
    if let greetingWindow, let andShow {
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

func renderTabsWindow(hotKey: HotKey, andShow: Bool? = nil) {
    func show() {
        guard andShow != nil else { return }
        filterTabs()
        tabsWindow?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    if tabsWindow != nil {
        show()
        return
    }

    let tabsView = NSHostingController(
        rootView: TabHistoryView(
            hotKey: hotKey,
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
    tabsWindow?.identifier = tabsWindowID
    
    show()
}

func showSettingsWindow() {
    if let settingsWindow {
        settingsWindow.makeKeyAndOrderFront(nil)
        return
    }
    
    let settingsView = NSHostingController(rootView: SettingsView())
    
    settingsWindow = Window()
        
    settingsWindow?.contentViewController = settingsView
    
    settingsWindow?.title = "Settings"
    settingsWindow?.setContentSize(NSSize(width: 300, height: 150))
    settingsWindow?.center()
    
    let controller = NSWindowController(window: settingsWindow)
    controller.showWindow(nil)
}

func hideTabsWindow() {
    tabsWindow?.orderOut(nil)
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var hotKey: HotKey
    var appState: AppState
    private var activeAppObserver: Any?
    
    init(
        appState: AppState
    ) {
        self.hotKey = HotKey(key: .tab, modifiers: [.option])
        self.appState = appState
    }
    
    private func handleHotKeyPress() {
        guard NSWorkspace.shared.frontmostApplication?.localizedName == "Safari" else {
            return
        }
        guard let tabs = Store.windows.windows.last?.tabs else { return }
        appState.tabIDsWithTitleAndHost = tabs
        appState.searchQuery = ""
        appState.indexOfTabToSwitchTo = 1
        startUsingTabFinder()
        appState.isUserOnboarded = true
        renderTabsWindow(hotKey: hotKey, andShow: true)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey.keyDownHandler = handleHotKeyPress
        renderGreetingWindow(andShow: true)
        renderTabsWindow(hotKey: hotKey)
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
        renderGreetingWindow()
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
                    self.hotKey.isPaused = false
                } else {
                    self.hotKey.isPaused = true
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
                let newFlags = event.modifierFlags.subtracting(.option)
                
                if NavigationKeys(rawValue: event.keyCode) != nil {
                    super.sendEvent(event)
                    return
                }
                
                guard let characters = event.charactersIgnoringModifiers else {
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
                    characters: characters,
                    charactersIgnoringModifiers: characters,
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

let delegate = AppDelegate(appState: appState)

let app = Application.shared
app.delegate = delegate

app.run()
