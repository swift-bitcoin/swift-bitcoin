import Foundation

/// The number -1 is pushed onto the stack.
func op1Negate(_ stack: inout [Data]) {
    stack.append(ScriptNumber.negativeOne.data)
}
