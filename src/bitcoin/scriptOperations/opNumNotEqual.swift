import Foundation

/// Returns 1 if the numbers are not equal, 0 otherwise.
func opNumNotEqual(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, b) = try getBinaryNumericParams(&stack, context: &context)
    stack.append(ScriptBoolean(a != b).data)
}
