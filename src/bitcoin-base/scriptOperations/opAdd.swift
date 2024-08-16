import Foundation

/// a is added to b.
func opAdd(_ stack: inout [Data], context: inout ScriptContext) throws {
    var a: ScriptNumber
    let b: ScriptNumber
    (a, b) = try getBinaryNumericParams(&stack, context: &context)
    try a.add(b)
    stack.append(a.data)
}
