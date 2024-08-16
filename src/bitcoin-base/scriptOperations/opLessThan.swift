import Foundation

/// Returns 1 if a is less than b, 0 otherwise.
func opLessThan(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, b) = try getBinaryNumericParams(&stack, context: &context)
    stack.append(ScriptBoolean(a.value < b.value).data)
}
