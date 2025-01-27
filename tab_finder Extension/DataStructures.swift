struct Tabs: Sequence {
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
