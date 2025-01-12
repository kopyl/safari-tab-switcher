import SafariServices
import SwiftUI

func pythonTrueModulo(_ a: Int, _ b: Int) -> Int {
    let remainder = a % b
    return remainder >= 0 ? remainder : remainder + b
}

struct TooltipView: View {
    @State private var tabTitles: [String: String] = [:]
    @State private var allOpenTabsUnique: [Int] = []
    @State private var eventMonitor: Any?
    @State private var indexOfTabToSwitchTo: Int = 1

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        let tabsToDisplay = Array(allOpenTabsUnique.reversed())
                        
                        ForEach(tabsToDisplay.indices, id: \.self) { tabIdx in
                            Text(tabTitles[String(tabsToDisplay[tabIdx])] ?? "No title")
                                .font(.system(size: 15))
                                .lineLimit(1)
                                .padding(.top, 10).padding(.bottom, tabIdx != tabsToDisplay.indices.last ? 10 : 20)
                                .padding(.leading, 10).padding(.trailing, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.blue.opacity(
                                    tabIdx == calculateTabToSwitchIndex(indexOfTabToSwitchTo)
                                    ? 1 : 0))
                                .id(tabIdx)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    indexOfTabToSwitchTo = tabIdx
                                    switchToTab()
                                }
                            
                            if tabIdx != tabsToDisplay.indices.last && tabIdx != tabsToDisplay.indices.first {
                                Divider().background(.gray.opacity(0.01))
                            }
                        }
                    }
                }
                .frame(width: 300, height: 800)
                .onChange(of: indexOfTabToSwitchTo) { newIndex in
                    withAnimation {
                        proxy.scrollTo(calculateTabToSwitchIndex(newIndex), anchor: .bottom)
                    }
                }
                .task {
                    tabTitles = Store.allOpenTabsUniqueWithTitles
                    allOpenTabsUnique = getOpenTabs().elements
                }
                .onAppear {
                    setupKeyListener()
                    indexOfTabToSwitchTo = 1
                }
                .onDisappear {
                    removeKeyListener()
                }
            }
        }
    }

    func calculateTabToSwitchIndex(_ indexOfTabToSwitchTo: Int) -> Int {
        return pythonTrueModulo(indexOfTabToSwitchTo, allOpenTabsUnique.count)
    }

    func setupKeyListener() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            handleKeyPress(event: event)
            return event
        }
    }

    func removeKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func switchToTab() {
        SafariExtensionViewController.shared.dismissPopover()
        Task {
            await switchToPreviousTab(by: calculateTabToSwitchIndex(indexOfTabToSwitchTo))
            
        }
    }

    func handleKeyPress(event: NSEvent) {
        guard !allOpenTabsUnique.isEmpty else { return }
        
        if event.modifierFlags.rawValue == 256 && event.keyCode == 58 {
            switchToTab()
            return
        }
        
        switch event.type {
        case .keyDown:
            switch event.keyCode {
            case 126:
                indexOfTabToSwitchTo -= 1
            case 50:  // `
                indexOfTabToSwitchTo -= 1
            case 125:
                indexOfTabToSwitchTo += 1
            case 48: // tab
                indexOfTabToSwitchTo += 1
            case 36: // tab
                switchToTab()
            default:
                break
            }
        default:
            break
        }
    }
}

func showPopover() async {
    guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
    guard let toolbarItem = await activeWindow.toolbarItem() else { return }
    toolbarItem.showPopover()
}

func switchToTab(id: Int) async {
    guard let activeWindow = await SFSafariApplication.activeWindow() else { return }
    let allTabs = await activeWindow.allTabs()
    
    guard allTabs.indices.contains(id) else {
        log("Previous tab ID \(id) is out of range.")
        return
    }
    await allTabs[id].activate()
    log("Switching to a tab")
}

func getTitlesAndHostsOfAllTabs(window: SFSafariWindow) async -> [String: String] {
    var pageTitles: [String: String] = [:]
    var pageHosts: [String: String] = [:]
    
    let tabs = await window.allTabs()
    for tab in tabs {
        if let activePage = await tab.activePage() {
            if let properties = await activePage.properties() {
                let key = tabs.firstIndex(of: tab) ?? -1
                
                if let title = properties.title {
                    pageTitles[String(key)] = title
                }
                if let host = properties.url?.host {
                    pageHosts[String(key)] = host
                }
            }
        }
    }
    return pageTitles
}

func getOpenTabs() -> OrderedSet<Int> {
    return OrderedSet(Store.allOpenTabsUnique)
}

func addNewTabToHistory(window: SFSafariWindow) async {
    var allOpenTabsUnique = getOpenTabs()
    let currentTabId = Store.currentTabId
    
    let tabs = await window.allTabs()
    guard let activeTab = await window.activeTab() else { return }
    let changedToTabIndex = tabs.firstIndex(of: activeTab) ?? currentTabId
    if changedToTabIndex == currentTabId {
        return
    }
    Store.currentTabId = changedToTabIndex

    allOpenTabsUnique.append(changedToTabIndex)
    Store.allOpenTabsUnique = allOpenTabsUnique.elements
}

func removeTabFromHistory() {
    let currentTabId = Store.currentTabId
    var allOpenTabsUnique = getOpenTabs()
    allOpenTabsUnique.remove(currentTabId)
    Store.allOpenTabsUnique = allOpenTabsUnique.elements
}

func switchToPreviousTab(by idx: Int) async {
    let allOpenTabsUnique = getOpenTabs()
    
    guard allOpenTabsUnique.count > 1 else {
            log("No previous tab to switch to.")
            return
        }

    let previousTabId = allOpenTabsUnique.elements.reversed()[idx]
    log("Switching to previous tab ID: \(previousTabId)")
    
    await switchToTab(id: previousTabId)
}

enum JScommands: String {
    case opttab
    case tabclose
}

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()

    override func loadView() {
        let swiftUIView = TooltipView()
        self.view = NSHostingView(rootView: swiftUIView)
    }}

class SafariExtensionHandler: SFSafariExtensionHandler {

    private func postDistributedNotification() {
        let notificationName = Notification.Name("com.tabfinder.example.notification")
        DistributedNotificationCenter.default().postNotificationName(notificationName, object: nil, deliverImmediately: true)
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        guard let command = JScommands(rawValue: messageName) else { return }
        switch command {
        case .opttab:
            postDistributedNotification()
        case .tabclose:
            removeTabFromHistory()
        }
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        Task {
            async let _ = addNewTabToHistory(window: window)
            async let _ = getTitlesAndHostsOfAllTabs(window: window)
        }
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
