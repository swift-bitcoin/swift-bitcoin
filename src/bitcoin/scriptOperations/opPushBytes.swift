import Foundation

/// This implementation covers operation codes `0x01` through `0x4e`. It includes `OP_PUSHBYTES` for array lengths up to 75 bytes as well as `OP_PUSHDATA1`, `OP_PUSHDATA2` and `OP_PUSHDATA1` for variable lenght data.
func opPushData(data: Data, stack: inout [Data]) {
    stack.append(data)
}
