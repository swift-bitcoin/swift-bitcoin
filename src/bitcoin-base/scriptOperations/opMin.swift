import Foundation

/// Returns the smaller of a and b.
func opMin(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, b) = try getBinaryNumericParams(&stack, context: &context)
    stack.append((a.value < b.value ? a : b).data)
}
