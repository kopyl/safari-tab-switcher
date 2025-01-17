struct OrderedSet2<Element: Hashable & Identifiable> where Element.ID: Hashable {
    public var elements: [Element] = []
    private var seenIDs: Set<Element.ID> = []
    
    init(_ elements: [Element]) {
        for element in elements {
            append(element)
        }
    }

    var count: Int { elements.count }
    var isEmpty: Bool { elements.isEmpty }

    subscript(index: Int) -> Element {
        let adjustedIndex = index < 0 ? elements.count + index : index
        precondition(adjustedIndex >= 0 && adjustedIndex < elements.count, "Index out of bounds")
        return elements[adjustedIndex]
    }

    func contains(_ element: Element) -> Bool {
        return seenIDs.contains(element.id)
    }

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

    mutating func remove(at index: Int) {
        let removedElement = elements.remove(at: index)
        seenIDs.remove(removedElement.id)
    }

    mutating func remove(_ element: Element) {
        guard let index = elements.firstIndex(where: { $0.id == element.id }) else { return }
        remove(at: index)
    }

    mutating func removeAll() {
        elements.removeAll()
        seenIDs.removeAll()
    }

    func index(of element: Element) -> Int? {
        return elements.firstIndex(where: { $0.id == element.id })
    }
    
    func filter(_ isIncluded: (Element) -> Bool) -> OrderedSet2 {
            let filteredElements = elements.filter(isIncluded)
            return OrderedSet2(filteredElements)
        }
}
