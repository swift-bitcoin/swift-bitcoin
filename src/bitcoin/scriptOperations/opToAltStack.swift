import Foundation

/// Puts the input onto the top of the alt stack. Removes it from the main stack.
func opToAltStack(_ stack: inout [Data], context: inout ScriptContext) throws {
    let first = try getUnaryParam(&stack)
    context.altStack.append(first)
}
