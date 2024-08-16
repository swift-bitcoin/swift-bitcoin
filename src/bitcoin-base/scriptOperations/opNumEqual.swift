import Foundation

/// Returns 1 if the numbers are equal, 0 otherwise.
func opNumEqual(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, b) = try getBinaryNumericParams(&stack, context: &context)
    stack.append(ScriptBoolean(a == b).data)
}
