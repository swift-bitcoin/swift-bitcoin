import Foundation

/// Duplicates the top three stack items.
func op3Dup(_ stack: inout [Data]) throws {
    let (first, second, third) = try getTernaryParams(&stack)
    stack.append(first)
    stack.append(second)
    stack.append(third)
    stack.append(first)
    stack.append(second)
    stack.append(third)
}
