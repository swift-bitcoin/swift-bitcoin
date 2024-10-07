import Foundation

/// A script operation.
public enum ScriptOperation: Equatable, Sendable {
    case zero, pushBytes(Data), pushData1(Data), pushData2(Data), pushData4(Data), oneNegate, /* reserved(UInt8), */ success(UInt8), constant(UInt8), noOp, /* ver, */ `if`, notIf, verIf, verNotIf, `else`, endIf, verify, `return`, toAltStack, fromAltStack, twoDrop, twoDup, threeDup, twoOver, twoRot, twoSwap, ifDup, depth, drop, dup, nip, over, pick, roll, rot, swap, tuck, cat, subStr, left, right, size, invert, and, or, xor, equal, equalVerify, oneAdd, oneSub, twoMul, twoDiv, negate, abs, not, zeroNotEqual, add, sub, mul, div, mod, lShift, rShift, boolAnd, boolOr, numEqual, numEqualVerify, numNotEqual, lessThan, greaterThan, lessThanOrEqual, greaterThanOrEqual, min, max, within, ripemd160, sha1, sha256, hash160, hash256, codeSeparator, checkSig, checkSigVerify, checkMultiSig, checkMultiSigVerify, noOp1, checkLockTimeVerify, checkSequenceVerify, noOp4, noOp5, noOp6, noOp7, noOp8, noOp9, noOp10, checkSigAdd, unknown(UInt8), pubKeyHash, pubKey, invalidOpCode

    init?(pushOpCode opCode: UInt8, _ data: Data) {
        var data = data
        switch opCode {
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

    public var isPush: Bool {
        switch self {
        case .zero, .oneNegate, .constant(_), .pushBytes(_), .pushData1(_), .pushData2(_), .pushData4(_): true
        default: false
        }
    }

    var isMinimalPush: Bool {
        switch self {
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
        return switch self {
        case .zero: 0x00
        case .pushBytes(let d): UInt8(d.count)
        case .pushData1(_): 0x4c
        case .pushData2(_): 0x4d
        case .pushData4(_): 0x4e
        case .oneNegate: 0x4f
        case .success(let k): k
        case .constant(let k): 0x50 + k
        case .noOp: 0x61
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

    func keyword(_ sigVersion: SigVersion = .witnessV1) -> String {
        operationPreconditions()
        return switch self {
        case .zero: "OP_0"
        case .pushBytes(_): "OP_PUSHBYTES"
        case .pushData1(_): "OP_PUSHDATA1"
        case .pushData2(_): "OP_PUSHDATA2"
        case .pushData4(_): "OP_PUSHDATA4"
        case .oneNegate: "OP_1NEGATE"
        case .success(let k):
            if sigVersion == .base || sigVersion == .witnessV0 {
                if k == 80 {
                    "OP_RESERVED"
                } else if k == 137 {
                    "OP_RESERVED1"
                } else if k == 138 {
                    "OP_RESERVED2"
                } else if k == 98 {
                    "OP_VER"
                } else {
                    "OP_UNKNOWN"
                }
            } else {
                "OP_SUCCESS\(k)"
            }
        case .constant(let k): "OP_\(k)"
        case .noOp: "OP_NOP"
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

    func operationPreconditions() {
        switch self {
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
        case .success(let k):
            precondition(k == 80 || k == 98 || (k >= 126 && k <= 129) || (k >= 131 && k <= 134) || (k >= 137 && k <= 138) || (k >= 141 && k <= 142) || (k >= 149 && k <= 153) || (k >= 187 && k <= 254))
        case .constant(let k):
            precondition(k > 0 && k < 17)
        case .unknown(let k):
            precondition(k >= 0xbb && k <= 0xfc)
        default: break
        }
    }

    func asm(_ sigVersion: SigVersion = .witnessV1) -> String {
        if case .pushBytes(let d) = self {
            return d.hex
        }
        return switch self {
        case .zero:
            "0"
        case .pushData1(let d), .pushData2(let d), .pushData4(let d):
            "\(keyword(sigVersion)) \(d.hex)"
        default: keyword(sigVersion)
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
            guard let number = try? ScriptNumber(value) else {
                preconditionFailure()
            }
            return encodeMinimally(number.data)
        }
    }

    public static func encodeMinimally(_ data: Data) -> ScriptOperation {
        switch data.count {
        case 0: .zero
        case 1...75: .pushBytes(data)
        case 76...Int(UInt8.max): .pushData1(data)
        case (Int(UInt8.max) + 1)...Int(UInt16.max): .pushData2(data)
        case (Int(UInt16.max) + 1)...Int(UInt32.max): .pushData4(data)
        default: preconditionFailure()
        }
    }
}

extension ScriptOperation {

    init?(_ data: Data) {
        var data = data
        guard data.count > 0 else {
            return nil
        }
        let opCode = data.withUnsafeBytes {  $0.load(as: UInt8.self) }
        data = data.dropFirst(MemoryLayout.size(ofValue: opCode))
        switch opCode {

        // OP_ZERO
        case Self.zero.opCode: self = .zero

        // OP_PUSHBYTES, OP_PUSHDATA1, OP_PUSHDATA2, OP_PUSHDATA4
        case 0x01 ... 0x4e: self.init(pushOpCode: opCode, data)

        // If any opcode numbered 80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254 is encountered, validation succeeds
        case Self.success(80).opCode,
            Self.success(98 /*0x62*/).opCode,
            Self.success(137).opCode ... Self.success(138).opCode,
            Self.success(126).opCode ... Self.success(129).opCode,
            Self.success(131).opCode ... Self.success(134).opCode,
            Self.success(141).opCode ... Self.success(142).opCode,
            Self.success(149).opCode ... Self.success(153).opCode,
            Self.success(187).opCode ... Self.success(254).opCode:
            self = .success(opCode)

        case Self.oneNegate.opCode: self = .oneNegate

            // Constants
        case Self.constant(1).opCode ... Self.constant(16).opCode:
            self = .constant(opCode - 0x50)

        case Self.noOp.opCode: self = .noOp

        case Self.if.opCode: self = .if
        case Self.notIf.opCode: self = .notIf
        case Self.verIf.opCode: self = .verIf
        case Self.verNotIf.opCode: self = .verNotIf
        case Self.else.opCode: self = .else
        case Self.endIf.opCode: self = .endIf
        case Self.verify.opCode: self = .verify
        case Self.return.opCode: self = .return
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
        case Self.cat.opCode: self = .cat
        case Self.subStr.opCode: self = .subStr
        case Self.left.opCode: self = .left
        case Self.right.opCode: self = .right
        case Self.size.opCode: self = .size
        case Self.invert.opCode: self = .invert
        case Self.and.opCode: self = .and
        case Self.or.opCode: self = .or
        case Self.xor.opCode: self = .xor
        case Self.equal.opCode: self = .equal
        case Self.equalVerify.opCode: self = .equalVerify
        case Self.oneAdd.opCode: self = .oneAdd
        case Self.oneSub.opCode: self = .oneSub
        case Self.twoMul.opCode: self = .twoMul
        case Self.twoDiv.opCode: self = .twoDiv
        case Self.negate.opCode: self = .negate
        case Self.abs.opCode: self = .abs
        case Self.not.opCode: self = .not
        case Self.zeroNotEqual.opCode: self = .zeroNotEqual
        case Self.add.opCode: self = .add
        case Self.sub.opCode: self = .sub
        case Self.mul.opCode: self = .mul
        case Self.div.opCode: self = .div
        case Self.mod.opCode: self = .mod
        case Self.lShift.opCode: self = .lShift
        case Self.rShift.opCode: self = .rShift
        case Self.boolAnd.opCode: self = .boolAnd
        case Self.boolOr.opCode: self = .boolOr
        case Self.numEqual.opCode: self = .numEqual
        case Self.numEqualVerify.opCode: self = .numEqualVerify
        case Self.numNotEqual.opCode: self = .numNotEqual
        case Self.lessThan.opCode: self = .lessThan
        case Self.greaterThan.opCode: self = .greaterThan
        case Self.lessThanOrEqual.opCode: self = .lessThanOrEqual
        case Self.greaterThanOrEqual.opCode: self = .greaterThanOrEqual
        case Self.min.opCode: self = .min
        case Self.max.opCode: self = .max
        case Self.within.opCode: self = .within
        case Self.ripemd160.opCode: self = .ripemd160
        case Self.sha1.opCode: self = .sha1
        case Self.sha256.opCode: self = .sha256
        case Self.hash160.opCode: self = .hash160
        case Self.hash256.opCode: self = .hash256
        case Self.codeSeparator.opCode: self = .codeSeparator
        case Self.checkSig.opCode: self = .checkSig
        case Self.checkSigVerify.opCode: self = .checkSigVerify
        case Self.checkMultiSig.opCode: self = .checkMultiSig
        case Self.checkMultiSigVerify.opCode: self = .checkMultiSigVerify
        case Self.noOp1.opCode: self = .noOp1
        case Self.checkLockTimeVerify.opCode: self = .checkLockTimeVerify
        case Self.checkSequenceVerify.opCode: self = .checkSequenceVerify
        case Self.noOp4.opCode: self = .noOp4
        case Self.noOp5.opCode: self = .noOp5
        case Self.noOp6.opCode: self = .noOp6
        case Self.noOp7.opCode: self = .noOp7
        case Self.noOp8.opCode: self = .noOp8
        case Self.noOp9.opCode: self = .noOp9
        case Self.noOp10.opCode: self = .noOp10
        case Self.checkSigAdd.opCode: self = .checkSigAdd
        case Self.unknown(0xbb).opCode ... Self.unknown(0xfc).opCode: self = .unknown(opCode)
        case Self.pubKeyHash.opCode: self = .pubKeyHash
        case Self.pubKey.opCode: self = .pubKey
        case Self.invalidOpCode.opCode: self = .invalidOpCode

        default: preconditionFailure()
        }
    }

    var data: Data {
        let opCodeData = withUnsafeBytes(of: opCode) { Data($0) }
        let lengthData: Data
        switch self {
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
        switch self {
        case .pushBytes(let d), .pushData1(let d), .pushData2(let d), .pushData4(let d):
            rawData = d
        default:
            rawData = Data()
        }
        return opCodeData + lengthData + rawData
    }

    var size: Int {
        operationPreconditions()
        let additionalSize: Int
        switch self {
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
}
