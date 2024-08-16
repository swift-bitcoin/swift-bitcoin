import Foundation

/// Returns 0 if the input is 0. 1 otherwise.
func op0NotEqual(_ stack: inout [Data], context: inout ScriptContext) throws {
    let a = try getUnaryNumericParam(&stack, context: &context)
    stack.append(ScriptBoolean(a != .zero).data)
}
