import Foundation

struct Windows: Sequence {
    public var windows: [_Window] = []
    public var windowCombinedIDs: Set<String> = []
    
    init() {}
    
    init(_ windows: [_Window]) {
        for window in windows {
            append(window)
        }

        self.windowCombinedIDs = Set(windows.map{$0.combinedID})
    }
    
    func getClosestWindowID(id: String) -> String {
        let windowIDsWithDistances = windowCombinedIDs.compactMap{ _id -> (_id: String, distance: Int) in
            return (_id, LevenshteinDistance.get(id, _id))
        }
        let bestMatch = windowIDsWithDistances.min{$0._id < $1._id}
        return bestMatch?._id ?? windowCombinedIDs.first!
    }
    
    func getClosest(windowCombinedID: String) -> _Window? {
        let closestWindowID = getClosestWindowID(id: windowCombinedID)
        return windows.first(where: {$0.combinedID == closestWindowID})
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
    
    func get(windowCombinedID: String) -> _Window? {
        return windows.first(where: {$0.combinedID == windowCombinedID})
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
    
    mutating func prepend(contentsOf _tabs: [Tab]) {
        var tabsToPrepend: [Tab] = []
        for tab in _tabs {
            if seenIDs.contains(tab.id) {
                continue
            }
            tabsToPrepend.append(tab)
        }
        tabs.insert(contentsOf: _tabs, at: 0)
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
