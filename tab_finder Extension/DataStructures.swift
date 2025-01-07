struct OrderedSet<Element: Hashable> {
    public var elements: [Element] = []
    private var seenElements: Set<Element> = []
    
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

    func index(of element: Element) -> Int? {
        return elements.firstIndex(of: element)
    }
}
