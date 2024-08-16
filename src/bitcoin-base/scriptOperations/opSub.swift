import Foundation

/// b is subtracted from a.
func opSub(_ stack: inout [Data], context: inout ScriptContext) throws {
    var (a, b) = try getBinaryNumericParams(&stack, context: &context)
    b.negate()
    try a.add(b)
    stack.append(a.data)
}
