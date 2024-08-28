import Foundation

/// A script operation.
public enum ScriptOperation: Equatable, Sendable {
    case zero, pushBytes(Data), pushData1(Data), pushData2(Data), pushData4(Data), oneNegate, reserved(UInt8), success(UInt8), constant(UInt8), noOp, ver, `if`, notIf, verIf, verNotIf, `else`, endIf, verify, `return`, toAltStack, fromAltStack, twoDrop, twoDup, threeDup, twoOver, twoRot, twoSwap, ifDup, depth, drop, dup, nip, over, pick, roll, rot, swap, tuck, cat, subStr, left, right, size, invert, and, or, xor, equal, equalVerify, oneAdd, oneSub, twoMul, twoDiv, negate, abs, not, zeroNotEqual, add, sub, mul, div, mod, lShift, rShift, boolAnd, boolOr, numEqual, numEqualVerify, numNotEqual, lessThan, greaterThan, lessThanOrEqual, greaterThanOrEqual, min, max, within, ripemd160, sha1, sha256, hash160, hash256, codeSeparator, checkSig, checkSigVerify, checkMultiSig, checkMultiSigVerify, noOp1, checkLockTimeVerify, checkSequenceVerify, noOp4, noOp5, noOp6, noOp7, noOp8, noOp9, noOp10, checkSigAdd, unknown(UInt8), pubKeyHash, pubKey, invalidOpCode

    init?(pushOpCode opCode: UInt8, _ data: Data) {
        var data = data
        switch(opCode) {
        case 0x01 ... 0x4b:
            let byteCount = Int(opCode)
            guard data.count >= byteCount else { return nil }
            let d = data.prefix(byteCount)
            self = .pushBytes(d)
        case 0x4c ... 0x4e:
            let byteCount: Int
            if opCode == 0x4c {
                let pushSize = data.withUnsafeBytes {  $0.loadUnaligned(as: UInt8.self) }
                data = data.dropFirst(MemoryLayout.size(ofValue: pushSize))
                byteCount = Int(pushSize)
            } else if opCode == 0x4d {
                let pushSize = data.withUnsafeBytes {  $0.loadUnaligned(as: UInt16.self) }
                data = data.dropFirst(MemoryLayout.size(ofValue: pushSize))
                byteCount = Int(pushSize)
            } else {
                // opCode == 0x4e
                let pushSize = data.withUnsafeBytes {  $0.loadUnaligned(as: UInt32.self) }
                data = data.dropFirst(MemoryLayout.size(ofValue: pushSize))
                byteCount = Int(pushSize)
            }
            guard data.count >= byteCount else { return nil }
            let d = data.prefix(byteCount)
            self = if opCode == 0x4c {
                .pushData1(d)
            } else if opCode == 0x4d {
                .pushData2(d)
            } else {
                // opCode == 0x4e
                .pushData4(d)
            }
        default:
            preconditionFailure()
        }
    }

    func operationPreconditions() {
        switch(self) {
        case .pushBytes(let d):
            precondition(d.count > 0 && d.count <= 75)
            break
        case .pushData1(let d):
            precondition(d.count >= 0 && d.count <= UInt8.max)
            break
        case .pushData2(let d):
            precondition(d.count >= 0 && d.count <= UInt16.max)
            break
        case .pushData4(let d):
            precondition(d.count >= 0 && d.count <= UInt32.max)
            break
        case .reserved(let k):
            precondition(k == 80 || (k >= 137 && k <= 138))
        case .success(let k):
            precondition(k == 80 || k == 98 || (k >= 126 && k <= 129) || (k >= 131 && k <= 134) || (k >= 137 && k <= 138) || (k >= 141 && k <= 142) || (k >= 149 && k <= 153) || (k >= 187 && k <= 254))
        case .constant(let k):
            precondition(k > 0 && k < 17)
        case .unknown(let k):
            precondition(k >= 0xbb && k <= 0xfc)
        default: break
        }
    }

    var isPush: Bool {
        switch(self) {
        case .zero, .oneNegate, .constant(_), .pushBytes(_), .pushData1(_), .pushData2(_), .pushData4(_): true
        default: false
        }
    }

    var isMinimalPush: Bool {
        switch(self) {
        case .pushBytes(let data):
            if data.count == 1 {
                if data.first! >= 1 && data.first! <= 16 {
                    return false
                }
                if data == ScriptNumber.negativeOne.data {
                    return false
                }
                return true
            }
            return true
        case .pushData1(let data):
            return data.count > 75
        case .pushData2(let data):
            return data.count > UInt8.max
        default:
            return true
        }
    }

    var opCode: UInt8 {
        operationPreconditions()
        return switch(self) {
        case .zero: 0x00
        case .pushBytes(let d): UInt8(d.count)
        case .pushData1(_): 0x4c
        case .pushData2(_): 0x4d
        case .pushData4(_): 0x4e
        case .oneNegate: 0x4f
        case .reserved(let k): k
        case .success(let k): k
        case .constant(let k): 0x50 + k
        case .noOp: 0x61
        case .ver: 0x62
        case .if: 0x63
        case .notIf: 0x64
        case .verIf: 0x65
        case .verNotIf: 0x66
        case .else: 0x67
        case .endIf: 0x68
        case .verify: 0x69
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
        case .size: 0x82
        case .invert: 0x83
        case .and: 0x84
        case .or: 0x85
        case .xor: 0x86
        case .equal: 0x87
        case .equalVerify: 0x88
        // case .reserved1: 0x89
        // case .reserved2: 0x8a
        case .oneAdd: 0x8b
        case .oneSub: 0x8c
        case .twoMul: 0x8d
        case .twoDiv: 0x8e
        case .negate: 0x8f
        case .abs: 0x90
        case .not: 0x91
        case .zeroNotEqual: 0x92
        case .add: 0x93
        case .sub: 0x94
        case .mul: 0x95
        case .div: 0x96
        case .mod: 0x97
        case .lShift: 0x98
        case .rShift: 0x99
        case .boolAnd: 0x9a
        case .boolOr: 0x9b
        case .numEqual: 0x9c
        case .numEqualVerify: 0x9d
        case .numNotEqual: 0x9e
        case .lessThan: 0x9f
        case .greaterThan: 0xa0
        case .lessThanOrEqual: 0xa1
        case .greaterThanOrEqual: 0xa2
        case .min: 0xa3
        case .max: 0xa4
        case .within: 0xa5
        case .ripemd160: 0xa6
        case .sha1: 0xa7
        case .sha256: 0xa8
        case .hash160: 0xa9
        case .hash256: 0xaa
        case .codeSeparator: 0xab
        case .checkSig: 0xac
        case .checkSigVerify: 0xad
        case .checkMultiSig: 0xae
        case .checkMultiSigVerify: 0xaf
        case .noOp1: 0xb0
        case .checkLockTimeVerify: 0xb1
        case .checkSequenceVerify: 0xb2
        case .noOp4: 0xb3
        case .noOp5: 0xb4
        case .noOp6: 0xb5
        case .noOp7: 0xb6
        case .noOp8: 0xb7
        case .noOp9: 0xb8
        case .noOp10: 0xb9
        case .checkSigAdd: 0xba
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
        case .oneNegate: "OP_1NEGATE"
        case .reserved(let k): "OP_RESERVED\(k == 80 ? "" : k == 137 ? "1" : "2")"
        case .success(let k): "OP_SUCCESS\(k)"
        case .constant(let k): "OP_\(k)"
        case .noOp: "OP_NOP"
        case .ver: "OP_VER"
        case .if: "OP_IF"
        case .notIf: "OP_NOTIF"
        case .verIf: "OP_VERIF"
        case .verNotIf: "OP_VERNOTIF"
        case .else: "OP_ELSE"
        case .endIf: "OP_ENDIF"
        case .verify: "OP_VERIFY"
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
        case .size: "OP_SIZE"
        case .invert: "OP_INVERT"
        case .and: "OP_AND"
        case .or: "OP_OR"
        case .xor: "OP_XOR"
        case .equal: "OP_EQUAL"
        case .equalVerify: "OP_EQUALVERIFY"
        case .oneAdd: "OP_1ADD"
        case .oneSub: "OP_1SUB"
        case .twoMul: "OP_2MUL"
        case .twoDiv: "OP_2DIV"
        case .negate: "OP_NEGATE"
        case .abs: "OP_ABS"
        case .not: "OP_NOT"
        case .zeroNotEqual: "OP_ZERONOTEQUAL"
        case .add: "OP_ADD"
        case .sub: "OP_SUB"
        case .mul: "OP_MUL"
        case .div: "OP_DIV"
        case .mod: "OP_MOD"
        case .lShift: "OP_LSHIFT"
        case .rShift: "OP_RSHIFT"
        case .boolAnd: "OP_BOOLAND"
        case .boolOr: "OP_BOOLOR"
        case .numEqual: "OP_NUMEQUAL"
        case .numEqualVerify: "OP_NUMEQUALVERIFY"
        case .numNotEqual: "OP_NUMNOTEQUAL"
        case .lessThan: "OP_LESSTHAN"
        case .greaterThan: "OP_GREATERTHAN"
        case .lessThanOrEqual: "OP_LESSTHANOREQUAL"
        case .greaterThanOrEqual: "OP_GREATERTHANOREQUAL"
        case .min: "OP_MIN"
        case .max: "OP_MAX"
        case .within: "OP_WITHIN"
        case .ripemd160: "OP_RIPEMD160"
        case .sha1: "OP_SHA1"
        case .sha256: "OP_SHA256"
        case .hash160: "OP_HASH160"
        case .hash256: "OP_HASH256"
        case .codeSeparator: "OP_CODESEPARATOR"
        case .checkSig: "OP_CHECKSIG"
        case .checkSigVerify: "OP_CHECKSIGVERIFY"
        case .checkMultiSig: "OP_CHECKMULTISIG"
        case .checkMultiSigVerify: "OP_CHECKMULTISIGVERIFY"
        case .noOp1: "OP_NOP1"
        case .checkLockTimeVerify: "OP_CHECKLOCKTIMEVERIFY"
        case .checkSequenceVerify: "OP_CHECKSEQUENCEVERIFY"
        case .noOp4: "OP_NOP4"
        case .noOp5: "OP_NOP5"
        case .noOp6: "OP_NOP6"
        case .noOp7: "OP_NOP7"
        case .noOp8: "OP_NOP8"
        case .noOp9: "OP_NOP9"
        case .noOp10: "OP_NOP10"
        case .checkSigAdd: "OP_CHECKSIGADD"
        case .unknown(_): "OP_UNKNOWN"
        case .pubKeyHash: "OP_PUBKEYHASH"
        case .pubKey: "OP_PUBKEY"
        case .invalidOpCode: "OP_INVALIDOPCODE"
        }
    }

    func execute(stack: inout [Data], context: inout ScriptContext) throws {
        operationPreconditions()

        // If branch consideration
        if !context.evaluateBranch {
            switch(self) {
            case .if, .notIf, .else, .endIf, .verIf, .verNotIf, .codeSeparator, .success(_):
                break
            default: return
            }
        }

        switch(self) {
        case .zero: opConstant(0, stack: &stack)
        case .pushBytes(let d), .pushData1(let d), .pushData2(let d), .pushData4(let d): try opPushBytes(data: d, stack: &stack, context: context)
        case .oneNegate: op1Negate(&stack)
        case .reserved(_): throw ScriptError.disabledOperation
        case .success(_): preconditionFailure()
        case .constant(let k): opConstant(k, stack: &stack)
        case .noOp: break
        case .ver: throw ScriptError.disabledOperation
        case .if: try opIf(&stack, context: &context)
        case .notIf: try opIf(&stack, isNotIf: true, context: &context)
        case .verIf, .verNotIf: throw ScriptError.disabledOperation
        case .else: try opElse(context: &context)
        case .endIf: try opEndIf(context: &context)
        case .verify: try opVerify(&stack)
        case .return: throw ScriptError.disabledOperation
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
        case .pick: try opPick(&stack, context: &context)
        case .roll: try opRoll(&stack, context: &context)
        case .rot: try opRot(&stack)
        case .swap: try opSwap(&stack)
        case .tuck: try opTuck(&stack)
        case .cat: throw ScriptError.disabledOperation
        case .subStr: throw ScriptError.disabledOperation
        case .left: throw ScriptError.disabledOperation
        case .right: throw ScriptError.disabledOperation
        case .size: try opSize(&stack)
        case .invert: throw ScriptError.disabledOperation
        case .and: throw ScriptError.disabledOperation
        case .or: throw ScriptError.disabledOperation
        case .xor: throw ScriptError.disabledOperation
        case .equal: try opEqual(&stack)
        case .equalVerify: try opEqualVerify(&stack)
        case .oneAdd: try op1Add(&stack, context: &context)
        case .oneSub:  try op1Sub(&stack, context: &context)
        case .twoMul: throw ScriptError.disabledOperation
        case .twoDiv: throw ScriptError.disabledOperation
        case .negate: try opNegate(&stack, context: &context)
        case .abs: try opAbs(&stack, context: &context)
        case .not: try opNot(&stack, context: &context)
        case .zeroNotEqual: try op0NotEqual(&stack, context: &context)
        case .add: try opAdd(&stack, context: &context)
        case .sub: try opSub(&stack, context: &context)
        case .mul: throw ScriptError.disabledOperation
        case .div: throw ScriptError.disabledOperation
        case .mod: throw ScriptError.disabledOperation
        case .lShift: throw ScriptError.disabledOperation
        case .rShift: throw ScriptError.disabledOperation
        case .boolAnd: try opBoolAnd(&stack, context: &context)
        case .boolOr: try opBoolOr(&stack, context: &context)
        case .numEqual: try opNumEqual(&stack, context: &context)
        case .numEqualVerify: try opNumEqualVerify(&stack, context: &context)
        case .numNotEqual: try opNumNotEqual(&stack, context: &context)
        case .lessThan: try opLessThan(&stack, context: &context)
        case .greaterThan: try opGreaterThan(&stack, context: &context)
        case .lessThanOrEqual: try opLessThanOrEqual(&stack, context: &context)
        case .greaterThanOrEqual: try opGreaterThanOrEqual(&stack, context: &context)
        case .min: try opMin(&stack, context: &context)
        case .max: try opMax(&stack, context: &context)
        case .within: try opWithin(&stack, context: &context)
        case .ripemd160: try opRIPEMD160(&stack)
        case .sha1: try opSHA1(&stack)
        case .sha256: try opSHA256(&stack)
        case .hash160: try opHash160(&stack)
        case .hash256: try opHash256(&stack)
        case .codeSeparator: try opCodeSeparator(context: &context)
        case .checkSig: try opCheckSig(&stack, context: &context)
        case .checkSigVerify: try opCheckSigVerify(&stack, context: &context)
        case .checkMultiSig:
            guard context.sigVersion == .base || context.sigVersion == .witnessV0 else { throw ScriptError.tapscriptCheckMultiSigDisabled }
            try opCheckMultiSig(&stack, context: &context)
        case .checkMultiSigVerify:
            guard context.sigVersion == .base || context.sigVersion == .witnessV0 else { throw ScriptError.tapscriptCheckMultiSigDisabled }
            try opCheckMultiSigVerify(&stack, context: &context)
        case .noOp1: if context.config.contains(.discourageUpgradableNoOps) { throw ScriptError.disallowedNoOp }
        case .checkLockTimeVerify:
            guard context.config.contains(.checkLockTimeVerify) else { break }
            try opCheckLockTimeVerify(&stack, context: context)
        case .checkSequenceVerify:
            guard context.config.contains(.checkSequenceVerify) else { break }
            try opCheckSequenceVerify(&stack, context: context)
        case .noOp4, .noOp5, .noOp6, .noOp7, .noOp8, .noOp9, .noOp10: if context.config.contains(.discourageUpgradableNoOps) { throw ScriptError.disallowedNoOp }
        case .checkSigAdd:
            guard context.sigVersion == .witnessV1 else { throw ScriptError.unknownOperation }
            try opCheckSigAdd(&stack, context: &context)
        case .unknown(_): throw ScriptError.unknownOperation
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

    public static func encodeMinimally(_ value: Int) -> ScriptOperation {
        switch value {
        case -1:
            return .oneNegate
        case 0:
            return .zero
        case 1...16:
            return .constant(UInt8(value))
        default:
            let data = Data(value: value)
            return .pushBytes(data)
        }
    }
}
