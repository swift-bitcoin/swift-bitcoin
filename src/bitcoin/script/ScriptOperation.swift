import Foundation

/// A script operation.
public enum ScriptOperation: Equatable {
    case zero, pushBytes(Data), pushData1(Data), pushData2(Data), pushData4(Data), reserved(UInt8), constant(UInt8), noOp, ver, verIf, verNotIf, `return`, toAltStack, fromAltStack, twoDrop, twoDup, threeDup, twoOver, twoRot, twoSwap, ifDup, depth, drop, dup, nip, over, pick, roll, rot, swap, tuck, cat, subStr, left, right, invert, and, or, xor, twoMul, twoDiv, mul, div, mod, lShift, rShift, codeSeparator, noOp1, noOp2, noOp3, noOp4, noOp5, noOp6, noOp7, noOp8, noOp9, noOp10, unknown(UInt8), pubKeyHash, pubKey, invalidOpCode

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
        case .reserved(let k): k
        case .constant(let k): 0x50 + k
        case .noOp: 0x61
        case .ver: 0x62
        case .verIf: 0x65
        case .verNotIf: 0x66
        case .return: 0x6a
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
        case .cat: 0x7e
        case .subStr: 0x7f
        case .left: 0x80
        case .right: 0x81
        case .invert: 0x83
        case .and: 0x84
        case .or: 0x85
        case .xor: 0x86
        // case .reserved1: 0x89
        // case .reserved2: 0x8a
        case .twoMul: 0x8d
        case .twoDiv: 0x8e
        case .mul: 0x95
        case .div: 0x96
        case .mod: 0x97
        case .lShift: 0x98
        case .rShift: 0x99
        case .codeSeparator: 0xab
        case .noOp1: 0xb0
        case .noOp2: 0xb1
        case .noOp3: 0xb2
        case .noOp4: 0xb3
        case .noOp5: 0xb4
        case .noOp6: 0xb5
        case .noOp7: 0xb6
        case .noOp8: 0xb7
        case .noOp9: 0xb8
        case .noOp10: 0xb9
        case .unknown(let k): k
        case .pubKeyHash: 0xfd
        case .pubKey: 0xfe
        case .invalidOpCode: 0xff
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
        case .reserved(let k): "OP_RESERVED\(k == 80 ? "" : k == 137 ? "1" : "2")"
        case .constant(let k): "OP_\(k)"
        case .noOp: "OP_NOP"
        case .ver: "OP_VER"
        case .verIf: "OP_VERIF"
        case .verNotIf: "OP_VERNOTIF"
        case .return: "OP_RETURN"
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
        case .cat: "OP_CAT"
        case .subStr: "OP_SUBSTR"
        case .left: "OP_LEFT"
        case .right: "OP_RIGHT"
        case .invert: "OP_INVERT"
        case .and: "OP_AND"
        case .or: "OP_OR"
        case .xor: "OP_XOR"
        case .twoMul: "OP_2MUL"
        case .twoDiv: "OP_2DIV"
        case .mul: "OP_MUL"
        case .div: "OP_DIV"
        case .mod: "OP_MOD"
        case .lShift: "OP_LSHIFT"
        case .rShift: "OP_RSHIFT"
        case .codeSeparator: "OP_CODESEPARATOR"
        case .noOp1: "OP_NOP1"
        case .noOp2: "OP_NOP2"
        case .noOp3: "OP_NOP3"
        case .noOp4: "OP_NOP4"
        case .noOp5: "OP_NOP5"
        case .noOp6: "OP_NOP6"
        case .noOp7: "OP_NOP7"
        case .noOp8: "OP_NOP8"
        case .noOp9: "OP_NOP9"
        case .noOp10: "OP_NOP10"
        case .unknown(_): "OP_UNKNOWN"
        case .pubKeyHash: "OP_PUBKEYHASH"
        case .pubKey: "OP_PUBKEY"
        case .invalidOpCode: "OP_INVALIDOPCODE"
        }
    }

    func execute(stack: inout [Data], context: inout ScriptContext) throws {
        operationPreconditions()
        switch(self) {
        case .zero: opConstant(0, stack: &stack)
        case .pushBytes(let d), .pushData1(let d), .pushData2(let d), .pushData4(let d): opPushData(data: d, stack: &stack)
        case .reserved(_): throw ScriptError.invalidScript
        case .constant(let k): opConstant(k, stack: &stack)
        case .noOp: break
        case .ver: throw ScriptError.invalidScript
        case .verIf, .verNotIf: throw ScriptError.invalidScript
        case .return: throw ScriptError.invalidScript
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
        case .cat: throw ScriptError.disabledOperation
        case .subStr: throw ScriptError.disabledOperation
        case .left: throw ScriptError.disabledOperation
        case .right: throw ScriptError.disabledOperation
        case .invert: throw ScriptError.disabledOperation
        case .and: throw ScriptError.disabledOperation
        case .or: throw ScriptError.disabledOperation
        case .xor: throw ScriptError.disabledOperation
        case .twoMul: throw ScriptError.disabledOperation
        case .twoDiv: throw ScriptError.disabledOperation
        case .mul: throw ScriptError.disabledOperation
        case .div: throw ScriptError.disabledOperation
        case .mod: throw ScriptError.disabledOperation
        case .lShift: throw ScriptError.disabledOperation
        case .rShift: throw ScriptError.disabledOperation
        case .codeSeparator: break
        case .noOp1, .noOp2, .noOp3, .noOp4, .noOp5, .noOp6, .noOp7, .noOp8, .noOp9, .noOp10: break
        case .unknown(_): throw ScriptError.invalidScript
        case .pubKeyHash: throw ScriptError.disabledOperation
        case .pubKey:  throw ScriptError.disabledOperation
        case .invalidOpCode: throw ScriptError.disabledOperation
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

        case Self.reserved(80).opCode,
             Self.reserved(137).opCode ... Self.reserved(138).opCode:
            self = .reserved(opCode)

        // Constants
        case Self.constant(1).opCode ... Self.constant(16).opCode:
            self = .constant(opCode - 0x50)

        case Self.noOp.opCode: self = .noOp

        // OP_VER / OP_SUCCESS
        case Self.ver.opCode: self = .ver
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
        case Self.noOp1.opCode: self = .noOp1
        case Self.noOp2.opCode: self = .noOp2
        case Self.noOp3.opCode: self = .noOp3
        case Self.noOp4.opCode: self = .noOp4
        case Self.noOp5.opCode: self = .noOp5
        case Self.noOp6.opCode: self = .noOp6
        case Self.noOp7.opCode: self = .noOp7
        case Self.noOp8.opCode: self = .noOp8
        case Self.noOp9.opCode: self = .noOp9
        case Self.noOp10.opCode: self = .noOp10
        case Self.unknown(0xbb).opCode ... Self.unknown(0xfc).opCode: self = .unknown(opCode)
        case Self.pubKeyHash.opCode: self = .pubKeyHash
        case Self.pubKey.opCode: self = .pubKey
        case Self.invalidOpCode.opCode: self = .invalidOpCode

        default: preconditionFailure()
        }
    }
}
