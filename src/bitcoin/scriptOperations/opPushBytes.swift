import Foundation

/// This implementation covers operation codes `0x01` through `0x4e`. It includes `OP_PUSHBYTES` for array lengths up to 75 bytes as well as `OP_PUSHDATA1`, `OP_PUSHDATA2` and `OP_PUSHDATA1` for variable lenght data.
func opPushBytes(data: Data, stack: inout [Data], context: ScriptContext) throws {
    // BIP141, BIP342
    if context.sigVersion != .base, data.count > BitcoinScript.maxStackElementSize {
        throw ScriptError.stackMaxElementSizeExceeded
    }
    stack.append(data)
}
