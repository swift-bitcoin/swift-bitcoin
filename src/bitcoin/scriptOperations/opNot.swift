import Foundation

/// If the input is 0 or 1, it is flipped. Otherwise the output will be 0.
func opNot(_ stack: inout [Data], context: inout ScriptContext) throws {
    let a = try getUnaryNumericParam(&stack, context: &context)
    stack.append(ScriptBoolean(a == .zero).data)
}
