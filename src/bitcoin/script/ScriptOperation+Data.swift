import Foundation

extension ScriptOperation {

    init?(_ data: Data, sigVersion: SigVersion = .base) {
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
        case 0x01 ... 0x4e: self.init(pushOpCode: opCode, data)

        case Self.reserved(80).opCode,
             Self.reserved(137).opCode ... Self.reserved(138).opCode:
            self = if sigVersion == .base || sigVersion == .witnessV0 {
                .reserved(opCode)
            } else {
                .success(opCode)
            }

        // If any opcode numbered 80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254 is encountered, validation succeeds
        case Self.success(126).opCode ... Self.success(129).opCode,
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

        // OP_VER / OP_SUCCESS
        case Self.ver.opCode:
            self = if sigVersion == .base || sigVersion == .witnessV0 {
                .ver
            } else {
                .success(opCode)
            }

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
}
