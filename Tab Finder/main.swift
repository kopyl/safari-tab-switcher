import Foundation
import HotKey
import AppKit

class AppState: ObservableObject {
    @Published var isUserOnboarded = false
    @Published var searchQuery = ""
    @Published var tabIDsWithTitleAndHost = Tabs()
    @Published var indexOfTabToSwitchTo = 1
    @Published var filteredTabs: [TabForSearch] = []
}

let appState = AppState()

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
        showTabsWindow(hotKey: hotKey)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        showGreetingWindow()
        setupAppSwitchingObserver()
        setUpNSWindowDelegate()
        hotKey.keyDownHandler = handleHotKeyPress
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
        showGreetingWindow()
        hideMainWindow()
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
            for url in urls {
                if url.scheme == "tabfinder" {
                    showGreetingWindow()
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
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        

        let aboutMenuItem = NSMenuItem(title: "About \(ProcessInfo.processInfo.processName)",
                                      action: #selector(orderFrontStandardAboutPanel(_:)),
                                      keyEquivalent: "")
        appMenu.addItem(aboutMenuItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "Quit \(ProcessInfo.processInfo.processName)",
                                     action: #selector(terminate(_:)),
                                     keyEquivalent: "q")
        appMenu.addItem(quitMenuItem)
        
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        
        let closeMenuItem = NSMenuItem(title: "Close Window",
           action: #selector(NSWindow.performClose(_:)),
           keyEquivalent: "w")
        
        windowMenu.addItem(closeMenuItem)
        
        self.mainMenu = mainMenu
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
