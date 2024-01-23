import Foundation

/// If both a and b are not 0, the output is 1. Otherwise 0.
func opBoolAnd(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, b) = try getBinaryNumericParams(&stack, context: &context)
    stack.append(ScriptBoolean(a != .zero && b != .zero).data)
}
