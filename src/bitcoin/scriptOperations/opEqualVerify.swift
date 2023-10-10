import Foundation

/// Same as ``opEqual`` (`OP_EQUAL`), but runs  ``opVerify`` (`OP_VERIFY`) afterward.
func opEqualVerify(_ stack: inout [Data]) throws {
    try opEqual(&stack)
    try opVerify(&stack)
}
