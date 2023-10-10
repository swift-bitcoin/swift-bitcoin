import Foundation

/// A script operation.
public enum ScriptOperation: Equatable {
    case zero, pushBytes(Data), pushData1(Data), pushData2(Data), pushData4(Data), constant(UInt8), toAltStack, fromAltStack, twoDrop, twoDup, threeDup, twoOver, twoRot, twoSwap, ifDup, depth, drop, dup, nip, over, pick, roll, rot, swap, tuck

    private func operationPreconditions() {
        switch(self) {
        case .pushBytes(let d):
            precondition(d.count > 0 && d.count <= 75)
        case .pushData1(let d):
            precondition(d.count > 75 && d.count <= UInt8.max)
        case .pushData2(let d):
            precondition(d.count > UInt8.max && d.count <= UInt16.max)
        case .pushData4(let d):
            precondition(d.count > UInt16.max && d.count <= UInt32.max)
        case .constant(let k):
            precondition(k > 0 && k < 17)
        default: break
        }
    }

    var size: Int {
        operationPreconditions()
        let additionalSize: Int
        switch(self) {
        case .pushBytes(let d):
            additionalSize = d.count
        case .pushData1(let d):
            additionalSize = MemoryLayout<UInt8>.size + d.count
        case .pushData2(let d):
            additionalSize = MemoryLayout<UInt16>.size + d.count
        case .pushData4(let d):
            additionalSize = MemoryLayout<UInt32>.size + d.count
        default:
            additionalSize = 0
        }
        return MemoryLayout<UInt8>.size + additionalSize
    }

    var opCode: UInt8 {
        operationPreconditions()
        return switch(self) {
        case .zero: 0x00
        case .pushBytes(let d): UInt8(d.count)
        case .pushData1(_): 0x4c
        case .pushData2(_): 0x4d
        case .pushData4(_): 0x4e
        case .constant(let k): 0x50 + k
        case .toAltStack: 0x6b
        case .fromAltStack: 0x6c
        case .twoDrop: 0x6d
        case .twoDup: 0x6e
        case .threeDup: 0x6f
        case .twoOver: 0x70
        case .twoRot: 0x71
        case .twoSwap: 0x72
        case .ifDup: 0x73
        case .depth: 0x74
        case .drop: 0x75
        case .dup: 0x76
        case .nip: 0x77
        case .over: 0x78
        case .pick: 0x79
        case .roll: 0x7a
        case .rot: 0x7b
        case .swap: 0x7c
        case .tuck: 0x7d
        }
    }

    var keyword: String {
        operationPreconditions()
        return switch(self) {
        case .zero: "OP_0"
        case .pushBytes(_): "OP_PUSHBYTES"
        case .pushData1(_): "OP_PUSHDATA1"
        case .pushData2(_): "OP_PUSHDATA2"
        case .pushData4(_): "OP_PUSHDATA4"
        case .constant(let k): "OP_\(k)"
        case .toAltStack: "OP_TOALTSTACK"
        case .fromAltStack: "OP_FROMALTSTACK"
        case .twoDrop: "OP_2DROP"
        case .twoDup: "OP_2DUP"
        case .threeDup: "OP_3DUP"
        case .twoOver: "OP_2OVER"
        case .twoRot: "OP_2ROT"
        case .twoSwap: "OP_2SWAP"
        case .ifDup: "OP_IFDUP"
        case .depth: "OP_DEPTH"
        case .drop: "OP_DROP"
        case .dup: "OP_DUP"
        case .nip: "OP_NIP"
        case .over: "OP_OVER"
        case .pick: "OP_PICK"
        case .roll: "OP_ROLL"
        case .rot: "OP_ROT"
        case .swap: "OP_SWAP"
        case .tuck: "OP_TUCK"
        }
    }

    func execute(stack: inout [Data], context: inout ScriptContext) throws {
        operationPreconditions()
        switch(self) {
        case .zero: opConstant(0, stack: &stack)
        case .pushBytes(let d), .pushData1(let d), .pushData2(let d), .pushData4(let d): opPushData(data: d, stack: &stack)
        case .constant(let k): opConstant(k, stack: &stack)
        case .toAltStack: try opToAltStack(&stack, context: &context)
        case .fromAltStack: try opFromAltStack(&stack, context: &context)
        case .twoDrop: try op2Drop(&stack)
        case .twoDup: try op2Dup(&stack)
        case .threeDup: try op3Dup(&stack)
        case .twoOver: try op2Over(&stack)
        case .twoRot: try op2Rot(&stack)
        case .twoSwap: try op2Swap(&stack)
        case .ifDup: try opIfDup(&stack)
        case .depth: try opDepth(&stack)
        case .drop: try opDrop(&stack)
        case .dup: try opDup(&stack)
        case .nip: try opNip(&stack)
        case .over: try opOver(&stack)
        case .pick: try opPick(&stack)
        case .roll: try opRoll(&stack)
        case .rot: try opRot(&stack)
        case .swap: try opSwap(&stack)
        case .tuck: try opTuck(&stack)
        }
    }

    var asm: String {
        if case .pushBytes(let d) = self {
            return d.hex
        }
        return switch(self) {
        case .zero:
            "0"
        case .pushData1(let d), .pushData2(let d), .pushData4(let d):
            "\(keyword) \(d.hex)"
        default: keyword
        }
    }

    var data: Data {
        let opCodeData = withUnsafeBytes(of: opCode) { Data($0) }
        let lengthData: Data
        switch(self) {
        case .pushData1(let d):
            lengthData = withUnsafeBytes(of: UInt8(d.count)) { Data($0) }
        case .pushData2(let d):
            lengthData = withUnsafeBytes(of: UInt16(d.count)) { Data($0) }
        case .pushData4(let d):
            lengthData = withUnsafeBytes(of: UInt32(d.count)) { Data($0) }
        default:
            lengthData = Data()
        }
        let rawData: Data
        switch(self) {
        case .pushBytes(let d), .pushData1(let d), .pushData2(let d), .pushData4(let d):
            rawData = d
        default:
            rawData = Data()
        }
        return opCodeData + lengthData + rawData
    }

    private init?(pushOpCode opCode: UInt8, _ data: Data, version: ScriptVersion) {
        var data = data
        switch(opCode) {
        case 0x01 ... 0x4b:
            let byteCount = Int(opCode)
            guard data.count >= byteCount else { return nil }
            let d = Data(data[..<(data.startIndex + byteCount)])
            self = .pushBytes(d)
        case 0x4c ... 0x4e:
            let byteCount: Int
            if opCode == 0x4c {
                let pushSize = data.withUnsafeBytes {  $0.load(as: UInt8.self) }
                data = data.dropFirst(MemoryLayout.size(ofValue: pushSize))
                byteCount = Int(pushSize)
            } else if opCode == 0x4d {
                let pushSize = data.withUnsafeBytes {  $0.load(as: UInt16.self) }
                data = data.dropFirst(MemoryLayout.size(ofValue: pushSize))
                byteCount = Int(pushSize)
            } else {
                // opCode == 0x4e
                let pushSize = data.withUnsafeBytes {  $0.load(as: UInt32.self) }
                data = data.dropFirst(MemoryLayout.size(ofValue: pushSize))
                byteCount = Int(pushSize)
            }
            guard data.count >= byteCount else { return nil }
            let d = Data(data[..<(data.startIndex + byteCount)])
            if opCode == 0x4c {
                self = .pushData1(d)
            } else if opCode == 0x4d {
                self = .pushData2(d)
            }
            // opCode == 0x4e
            self = .pushData4(d)
        default:
            preconditionFailure()
        }
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

        // OP_PUSHBYTES, OP_PUSHDATA1, OP_PUSHDATA2, OP_PUSHDATA4
        case 0x01 ... 0x4e: self.init(pushOpCode: opCode, data, version: version)

        // Constants
        case Self.constant(1).opCode ... Self.constant(16).opCode:
            self = .constant(opCode - 0x50)

        case Self.toAltStack.opCode: self = .toAltStack
        case Self.fromAltStack.opCode: self = .fromAltStack
        case Self.twoDrop.opCode: self = .twoDrop
        case Self.twoDup.opCode: self = .twoDup
        case Self.threeDup.opCode: self = .threeDup
        case Self.twoOver.opCode: self = .twoOver
        case Self.twoRot.opCode: self = .twoRot
        case Self.twoSwap.opCode: self = .twoSwap
        case Self.ifDup.opCode: self = .ifDup
        case Self.depth.opCode: self = .depth
        case Self.drop.opCode: self = .drop
        case Self.dup.opCode: self = .dup
        case Self.nip.opCode: self = .nip
        case Self.over.opCode: self = .over
        case Self.pick.opCode: self = .pick
        case Self.roll.opCode: self = .roll
        case Self.rot.opCode: self = .rot
        case Self.swap.opCode: self = .swap
        case Self.tuck.opCode: self = .tuck
        default: preconditionFailure()
        }
    }
}
