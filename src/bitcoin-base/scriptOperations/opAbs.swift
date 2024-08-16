import Foundation

/// The input is made positive.
func opAbs(_ stack: inout [Data], context: inout ScriptContext) throws {
    var a = try getUnaryNumericParam(&stack, context: &context)
    if a.value < 0 {
        a.negate()
    }
    stack.append(a.data)
}
