import Foundation

extension Array {
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}

extension Array {
    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, [ValueType]>, contains other: ValueType) -> [Element] {
        return self.filter { element in
            return element[keyPath: keyPath].contains(other)
        }
    }

    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, isElementOf other: [ValueType]) -> [Element] {
        return self.filter { element in
            return other.contains(element[keyPath: keyPath])
        }
    }

    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, equals other: ValueType) -> [Element] {
        return self.filter { element in
            return element[keyPath: keyPath] == other
        }
    }

    func first<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, equals other: ValueType) -> Element? {
        return self.first { element in
            return element[keyPath: keyPath] == other
        }
    }

    func filter(where keyPath: KeyPath<Element, Bool>) -> [Element] {
        return self.filter { element in
            return element[keyPath: keyPath] == true
        }
    }

    func filter<ValueType>(_ keyPath: KeyPath<Element, ValueType>, predicate: (ValueType) -> Bool) -> [Element] {
        return self.filter { element in
            let field = element[keyPath: keyPath]
            return predicate(field)
        }
    }

    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, notEquals other: ValueType) -> [Element] {
        return self.filter { element in
            return element[keyPath: keyPath] != other
        }
    }

    func excluding(_ excludingElement: Element) -> [Element] where Element: Equatable {
        return self.filter { element in
            return element != excludingElement
        }
    }

    func excluding(_ excludingElements: [Element]) -> [Element] where Element: Equatable {
        return self.filter { element in
            return !excludingElements.contains(element)
        }
    }

    func contains<ValueType: Equatable>(_ keyPath: KeyPath<Element, ValueType>, equalTo other: ValueType) -> Bool {
        return self.contains(where: { $0[keyPath: keyPath] == other })
    }

    func contains(_ element: Element) -> Bool where Element: Equatable {
        return self.contains(where: { $0 == element })
    }

    func sorted<ValueType: Comparable>(on keyPath: KeyPath<Element, ValueType>,
                                       using comparator: (ValueType, ValueType) -> Bool) -> [Element] {
        return self.sorted(by: { a, b in
            return comparator(a[keyPath: keyPath], b[keyPath: keyPath])
        })
    }
}

extension Array where Element: Hashable {
    func unique() -> Set<Element> {
        return Set(self)
    }

    func asSet() -> Set<Element> {
        return unique()
    }
}

extension Array where Element: Equatable {
    func contains(anyOf other: [Element]) -> Bool {
        for element in other {
            if self.contains(element) {
                return true
            }
        }
        return false
    }
}

extension Set {
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}

extension Set {
    func first<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, equals other: ValueType) -> Element? {
        return self.first { element in
            return element[keyPath: keyPath] == other
        }
    }

    func filter<ValueType>(_ keyPath: KeyPath<Element, ValueType>, predicate: (ValueType) -> Bool) -> Set<Element> {
        return self.filter { element in
            let field = element[keyPath: keyPath]
            return predicate(field)
        }
    }

    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, equals other: ValueType) -> Set<Element> {
        return self.filter { element in
            return element[keyPath: keyPath] == other
        }
    }

    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, notEquals other: ValueType) -> Set<Element> {
        return self.filter { element in
            return element[keyPath: keyPath] != other
        }
    }

    func filter<ValueType: Equatable>(where keyPath: KeyPath<Element, ValueType>, isElementOf other: Set<ValueType>) -> Set<Element> {
        return self.filter { element in
            return other.contains(element[keyPath: keyPath])
        }
    }

    func contains<ValueType: Equatable>(_ keyPath: KeyPath<Element, ValueType>, equalTo other: ValueType) -> Bool {
        return self.contains(where: { $0[keyPath: keyPath] == other })
    }

    func contains(_ keyPath: KeyPath<Element, Bool>) -> Bool {
        return self.contains(where: { $0[keyPath: keyPath] == true })
    }

    func contains(_ element: Element) -> Bool where Element: Equatable {
        return self.contains(where: { $0 == element })
    }

    func excluding(_ excludingElement: Element) -> Set<Element> where Element: Equatable {
        return self.filter { element in
            return element != excludingElement
        }
    }

    var array: [Element] {
        return Array(self)
    }
}
