struct OrderedSet: Sequence {
    public var tabs: [TabInfoWithID] = []
    private var seenIDs: Set<Int> = []
    
    init() {}
    
    init(_ tabs: [TabInfoWithID]) {
        for tab in tabs {
            append(tab)
        }
    }

    var isEmpty: Bool { tabs.isEmpty }

    mutating func append(_ tab: Element) {
        if seenIDs.contains(tab.id) {
            if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs.remove(at: index)
            }
            seenIDs.remove(tab.id)
        }
        tabs.append(tab)
        seenIDs.insert(tab.id)
    }
    
    mutating func append(contentsOf: [Element]) {
        var elementsToPrepend: [Element] = []
        for element in contentsOf {
            if seenIDs.contains(element.id) {
                continue
            }
            elementsToPrepend.append(element)
        }
        tabs.insert(contentsOf: elementsToPrepend, at: 0)
    }
    
    func filter(_ isIncluded: (Element) -> Bool) -> OrderedSet {
            let filteredElements = tabs.filter(isIncluded)
            return OrderedSet(filteredElements)
        }
    
    var count: Int {
        get {
            return tabs.count
        }
    }
    
    func makeIterator() -> IndexingIterator<[TabInfoWithID]> {
        return tabs.makeIterator()
    }
}
