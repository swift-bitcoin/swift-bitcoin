import Foundation

/// Returns 1 if x is within the specified range (left-inclusive), 0 otherwise.
func opWithin(_ stack: inout [Data]) throws {
    let (first, second, third) = try getTernaryParams(&stack)
    let a = try ScriptNumber(first)
    let min = try ScriptNumber(second)
    let max = try ScriptNumber(third)
    stack.append(ScriptBoolean(min.value <= a.value && a.value < max.value).data)
}
