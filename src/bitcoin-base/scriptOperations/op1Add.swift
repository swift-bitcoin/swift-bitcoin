import Foundation

/// 1 is added to the input.
func op1Add(_ stack: inout [Data], context: inout ScriptContext) throws {
    var a = try getUnaryNumericParam(&stack, context: &context)
    try a.add(.one)
    stack.append(a.data)
}
