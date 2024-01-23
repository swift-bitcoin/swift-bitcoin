import Foundation

/// The sign of the input is flipped.
func opNegate(_ stack: inout [Data], context: inout ScriptContext) throws {
    var a = try getUnaryNumericParam(&stack, context: &context)
    a.negate()
    stack.append(a.data)
}
