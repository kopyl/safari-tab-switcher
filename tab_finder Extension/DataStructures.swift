struct OrderedSet<Element: Hashable>: Sequence, RandomAccessCollection {
    public var elements: [Element] = []
    private var seenElements: Set<Element> = []
    
    init() { }
    
    init(_ elements: [Element]) {
            for element in elements {
                append(element)
            }
        }

    var count: Int { elements.count }
    var isEmpty: Bool { elements.isEmpty }
    
    var startIndex: Int { return elements.startIndex }
    var endIndex: Int { return elements.endIndex }

    subscript(index: Int) -> Element {
            let adjustedIndex = index < 0 ? elements.count + index : index
            precondition(adjustedIndex >= 0 && adjustedIndex < elements.count, "Index out of bounds")
            return elements[adjustedIndex]
        }

    func contains(_ element: Element) -> Bool {
        return seenElements.contains(element)
    }

    mutating func append(_ element: Element) {
        if seenElements.contains(element) {
            if let index = elements.firstIndex(of: element) {
                elements.remove(at: index)
            }
            seenElements.remove(element)
        }
        elements.append(element)
        seenElements.insert(element)
    }
    
    mutating func append(contentsOf: [Element]) {
        var elementsToPrepend: [Element] = []
        for element in contentsOf {
            if seenElements.contains(element) {
                continue
            }
            elementsToPrepend.append(element)
        }
        elements.insert(contentsOf: elementsToPrepend, at: 0)
    }

    mutating func remove(at index: Int) {
        let removedElement = elements.remove(at: index)
        seenElements.remove(removedElement)
    }

    mutating func remove(_ element: Element) {
        guard let index = elements.firstIndex(of: element) else { return }
        remove(at: index)
    }

    mutating func removeAll() {
        elements.removeAll()
        seenElements.removeAll()
    }
    
    mutating func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        let elementsToKeep = try elements.filter { try !shouldBeRemoved($0) }
        seenElements = Set(elementsToKeep)
        elements = elementsToKeep
    }

    func index(of element: Element) -> Int? {
        return elements.firstIndex(of: element)
    }
    
    func makeIterator() -> IndexingIterator<[Element]> {
            return elements.makeIterator()
    }
    
    func reversed() -> OrderedSet<Element> {
            var reversedSet = OrderedSet<Element>()
            reversedSet.elements = elements.reversed()
            for element in reversedSet.elements {
                reversedSet.seenElements.insert(element)
            }
            return reversedSet
        }
}
