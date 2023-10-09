import Foundation

/// A script operation.
public enum ScriptOperation: Equatable {
    case zero, constant(UInt8), toAltStack, fromAltStack, twoDrop, twoDup, threeDup, twoOver, twoRot, twoSwap, ifDup, depth, drop, dup, nip, over, pick, roll, rot, swap, tuck

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
