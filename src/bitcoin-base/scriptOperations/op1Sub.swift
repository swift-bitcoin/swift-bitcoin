import Foundation

/// b is subtracted from a.
func op1Sub(_ stack: inout [Data], context: inout ScriptContext) throws {
    var a = try getUnaryNumericParam(&stack, context: &context)
    try a.add(.negativeOne)
    stack.append(a.data)
}
