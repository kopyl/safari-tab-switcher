import Foundation
import HotKey
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var showOrHideTabsHistoryWindowHotKey: HotKey?
    var appState: AppState?
    private var activeAppObserver: Any?
    
    init(
        showOrHideTabsHistoryWindowHotKey: HotKey,
        appState: AppState
    ) {
        self.showOrHideTabsHistoryWindowHotKey = showOrHideTabsHistoryWindowHotKey
        self.appState = appState
    }
    
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

let delegate = AppDelegate(
    showOrHideTabsHistoryWindowHotKey: HotKey(key: .tab, modifiers: [.option]),
    appState: AppState()
)

let app = Application.shared
app.delegate = delegate

app.run()
