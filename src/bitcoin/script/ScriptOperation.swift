import Foundation

/// A script operation.
enum ScriptOperation: Equatable {
    case zero

    var size: Int {
        MemoryLayout<UInt8>.size
    }

    var opCode: UInt8 {
        switch(self) {
        case .zero: 0x00
        }
    }

    var keyword: String {
        switch(self) {
        case .zero: "OP_0"
        }
    }

    func execute(stack: inout [Data], context: inout ScriptContext) throws {
        switch(self) {
        case .zero: opConstant(0, stack: &stack)
        }
    }

    var asm: String {
        switch(self) {
        case .zero:
            return "0"
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
        default: fatalError()
        }
    }
}
