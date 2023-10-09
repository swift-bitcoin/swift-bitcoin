import Foundation

/// A script operation.
public enum ScriptOperation: Equatable {
    case zero, constant(UInt8)

    private func operationPreconditions() {
        switch(self) {
        case .constant(let k):
            precondition(k > 0 && k < 17)
        default: break
        }
    }

    var size: Int {
        operationPreconditions()
        return MemoryLayout<UInt8>.size
    }

    var opCode: UInt8 {
        operationPreconditions()
        return switch(self) {
        case .zero: 0x00
        case .constant(let k): 0x50 + k
        }
    }

    var keyword: String {
        operationPreconditions()
        return switch(self) {
        case .zero: "OP_0"
        case .constant(let k): "OP_\(k)"
        }
    }

    func execute(stack: inout [Data], context: inout ScriptContext) throws {
        operationPreconditions()
        switch(self) {
        case .zero: opConstant(0, stack: &stack)
        case .constant(let k): opConstant(k, stack: &stack)
        }
    }

    var asm: String {
        return switch(self) {
        case .zero: "0"
        default: keyword
        }
    }

    var data: Data {
        let opCodeData = withUnsafeBytes(of: opCode) { Data($0) }
        return opCodeData
    }

    init?(_ data: Data, version: ScriptVersion = .legacy) {
        var data = data
        guard data.count > 0 else {
            return nil
        }
        let opCode = data.withUnsafeBytes {  $0.load(as: UInt8.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: opCode))
        switch(opCode) {
        // OP_ZERO
        case Self.zero.opCode: self = .zero

        // Constants
        case Self.constant(1).opCode ... Self.constant(16).opCode:
            self = .constant(opCode - 0x50)

        default: preconditionFailure()
        }
    }
}
