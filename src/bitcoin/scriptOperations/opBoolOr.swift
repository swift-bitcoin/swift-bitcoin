import Foundation

/// If a or b is not 0, the output is 1. Otherwise 0.
func opBoolOr(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, b) = try getBinaryNumericParams(&stack, context: &context)
    stack.append(ScriptBoolean(a != .zero || b != .zero).data)
}
