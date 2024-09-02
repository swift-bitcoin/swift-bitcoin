import Foundation

extension ScriptContext {
    
    /// Implementation of a constant script operation.
    mutating func opConstant(_ k: UInt8) {
        stack.append(ScriptNumber(k).data)
    }
    
    /// Pushes the string length of the top element of the stack (without popping it).
    mutating func opSize() throws {
        let first = try getUnaryParam()
        stack.append(first)
        let n = try ScriptNumber(first.count)
        stack.append(n.data)
    }

    /// This implementation covers operation codes `0x01` through `0x4e`. It includes `OP_PUSHBYTES` for array lengths up to 75 bytes as well as `OP_PUSHDATA1`, `OP_PUSHDATA2` and `OP_PUSHDATA1` for variable lenght data.
    mutating func opPushBytes(data: Data) throws {
        guard !config.contains(.minimalData) || currentOp.isMinimalPush else {
            throw ScriptError.nonMinimalPush
        }
        // BIP141, BIP342
        if sigVersion != .base, data.count > BitcoinScript.maxStackElementSize {
            throw ScriptError.stackMaxElementSizeExceeded
        }
        stack.append(data)
    }
}
