import Foundation

enum WindowsParseError: String, LocalizedError {
    case ArraysCountMismatch
    case SimilarStringNotFound
    
    var errorDescription: String? {
        rawValue
    }
}

struct Windows: Sequence {
    public var windows: [_Window] = []
    private var windowCombinedIDs: Set<String> = []
    
    init() {}
    
    init(_ windows: [_Window]) {
        for window in windows {
            append(window)
        }

        self.windowCombinedIDs = Set(windows.map{$0.combinedID})
    }
    
    func getClosestWindowID(id: String) -> String {
        let windowIDsWithDistances = windowCombinedIDs.compactMap{ _id -> (_id: String, distance: Int) in
            if _id.isEmpty || id.isEmpty {
                return (_id, 0)
            }
            return (_id, levenshtein(sourceString: id, target: _id))
        }
        let bestMatch = windowIDsWithDistances.min{$0._id < $1._id}
        return bestMatch?._id ?? windowCombinedIDs.first!
    }
    
    mutating func removeNonExisting(_ currentWindows: Windows) {
        var closestMatchesByWindowID: [String] = []
        for window in currentWindows {
            let closestMatchByWindowID = getClosestWindowID(id: window.combinedID)
            closestMatchesByWindowID.append(closestMatchByWindowID)
        }
        
        windows = currentWindows.filter { window in
            closestMatchesByWindowID.contains(window.combinedID)
        }
    }
    
    mutating func append(_ window: _Window) {
        windows.append(window)
        windowCombinedIDs.insert(window.combinedID)
    }
    
    mutating func replace(_ window: _Window) throws {
        if windowCombinedIDs.isEmpty {
            append(window)
        }
        
        if windows.count == 1 {
            guard windowCombinedIDs.count == 1 else {
                throw WindowsParseError.ArraysCountMismatch
            }
            
            windows.removeFirst()
            windows.append(window)
            
            windowCombinedIDs.removeFirst()
            windowCombinedIDs.insert(window.combinedID)

            return
        }
        
        let closestWindowID = getClosestWindowID(id: window.combinedID)
        guard let index = windows.firstIndex(where: { $0.combinedID == closestWindowID }) else {
            throw WindowsParseError.SimilarStringNotFound
        }
        windows.remove(at: index)
        windowCombinedIDs.remove(closestWindowID)
        
        windows.append(window)
        windowCombinedIDs.insert(window.combinedID)
    }
    
    func makeIterator() -> IndexingIterator<[_Window]> {
        return windows.makeIterator()
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
