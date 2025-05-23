import Foundation
import SafariServices

struct Windows: Sequence {
    public var windows: [_Window] = []
    public var windowCombinedIDs: Set<String> = []
    
    init() {}
    
    init(_ windows: [_Window]) {
        for window in windows {
            append(window)
        }

        self.windowCombinedIDs = Set(windows.map(\.combinedID))
    }
    
    mutating func append(_ window: _Window) {
        windows.append(window)
        windowCombinedIDs.insert(window.combinedID)
        self.deduplicate()
    }
    
    func makeIterator() -> IndexingIterator<[_Window]> {
        return windows.makeIterator()
    }
    
    func filter(_ window: (_Window) -> Bool) -> Windows {
            let filteredElements = windows.filter(window)
            return Windows(filteredElements)
        }
    
    mutating func deduplicate() {
        var seenCombinedIDs = Set<String>()
        var uniqueWindows = [_Window]()

        for window in windows.reversed() {
            if !seenCombinedIDs.contains(window.combinedID) {
                seenCombinedIDs.insert(window.combinedID)
                uniqueWindows.append(window)
            }
        }

        self.windows = uniqueWindows.reversed()
        self.windowCombinedIDs = seenCombinedIDs
    }
    
    func get(SFWindow: SFSafariWindow) async -> _Window? {
        let windowID = await SFWindow.id()
        return windows.first(where: {$0.combinedID == windowID})
    }
}

struct Tabs: Sequence, Codable {
    public var tabs: [Tab] = []
    private var seenIDs: Set<Int> = []
    
    init() {}
    
    init(_ tabs: [Tab]) {
        for tab in tabs {
            append(tab)
        }
    }

    var isEmpty: Bool { tabs.isEmpty }

    mutating func append(_ tab: Tab) {
        if seenIDs.contains(tab.id) {
            if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs.remove(at: index)
            }
            seenIDs.remove(tab.id)
        }
        tabs.append(tab)
        seenIDs.insert(tab.id)
    }
    
    mutating func append(contentsOf _tabs: [Tab]) {
        var tabsToAppend: [Tab] = []
        for tab in _tabs {
            if seenIDs.contains(tab.id) {
                continue
            }
            tabsToAppend.append(tab)
        }
        tabs.insert(contentsOf: tabsToAppend, at: tabs.count)
    }
    
    func filter(_ tab: (Tab) -> Bool) -> Tabs {
            let filteredElements = tabs.filter(tab)
            return Tabs(filteredElements)
        }
    
    var count: Int {
        tabs.count
    }
    
    func makeIterator() -> IndexingIterator<[Tab]> {
        return tabs.makeIterator()
    }
}

extension SFSafariWindow {
    func id() async -> String {
        let allTabs = await self.allTabs()
        var tabs = Array<Tab?>(repeating: nil, count: allTabs.count)

        await withTaskGroup(of: (Int, Tab)?.self) { group in
            for (index, tab) in allTabs.enumerated() {
                group.addTask {
                    return (index, await Tab(id: index, tab: tab))
                }
            }

            for await (index, tab) in group.compactMap({ $0 }) {
                tabs[index] = tab
            }
        }

        let newWindow = _Window(tabs: Tabs(tabs.compactMap { $0 }))
        return newWindow.combinedID
    }
}
