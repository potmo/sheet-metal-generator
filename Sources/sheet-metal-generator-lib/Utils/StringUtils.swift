import Foundation

public extension String {
    func leftpad(to length: Int, with character: Character = " ") -> String {
        var outString: String = self
        let extraLength = max(0, length - outString.count)

        return Array(repeating: character, count: extraLength)
            .map(String.init)
            .joined(separator: "") + self
    }
}
