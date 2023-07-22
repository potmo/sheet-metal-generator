import Foundation

infix operator %%

// This works as expected in both directions and for positive and negative numbers
extension Int {
    static func %% (_ left: Int, _ right: Int) -> Int {
        if left >= 0 {
            return left % right
        }
        if left >= -right {
            return (left + right)
        }
        return ((left % right) + right) % right
    }
}
