struct OrderedSet<Element: Hashable & Identifiable> where Element.ID: Hashable {
    public var elements: [Element] = []
    private var seenIDs: Set<Element.ID> = []
    
    init() {}
    
    init(_ elements: [Element]) {
        for element in elements {
            append(element)
        }
    }

    var isEmpty: Bool { elements.isEmpty }

    mutating func append(_ element: Element) {
        if seenIDs.contains(element.id) {
            if let index = elements.firstIndex(where: { $0.id == element.id }) {
                elements.remove(at: index)
            }
            seenIDs.remove(element.id)
        }
        elements.append(element)
        seenIDs.insert(element.id)
    }
    
    mutating func append(contentsOf: [Element]) {
        var elementsToPrepend: [Element] = []
        for element in contentsOf {
            if seenIDs.contains(element.id) {
                continue
            }
            elementsToPrepend.append(element)
        }
        elements.insert(contentsOf: elementsToPrepend, at: 0)
    }
    
    func filter(_ isIncluded: (Element) -> Bool) -> OrderedSet {
            let filteredElements = elements.filter(isIncluded)
            return OrderedSet(filteredElements)
        }
    
    var count: Int {
        get {
            return elements.count
        }
    }
}
