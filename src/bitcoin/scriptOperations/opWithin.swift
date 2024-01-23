import Foundation

/// Returns 1 if x is within the specified range (left-inclusive), 0 otherwise.
func opWithin(_ stack: inout [Data], context: inout ScriptContext) throws {
    let (a, min, max) = try getTernaryNumericParams(&stack, context: &context)
    stack.append(ScriptBoolean(min.value <= a.value && a.value < max.value).data)
}
