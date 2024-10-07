import Foundation

/// Bitcoin SCRIPT execution context.
///
/// Use a single `ScriptContext` instance to run multiple scripts sequentially.
public struct ScriptContext {

    init?(_ config: ScriptConfig = .standard, transaction: BitcoinTransaction, inputIndex: Int = 0, prevout: TransactionOutput) {
        guard transaction.inputs.count > 0, inputIndex < transaction.inputs.count else {
            return nil
        }
        self.init(config, transaction: transaction, inputIndex: inputIndex, prevouts: [prevout])
    }

    public init(_ config: ScriptConfig = .standard, transaction: BitcoinTransaction = .dummy, inputIndex: Int = 0, prevouts: [TransactionOutput] = []) {
        self.config = config
        self.transaction = transaction
        self.inputIndex = inputIndex
        self.prevouts = prevouts
        self.sigVersion = .base
    }

    public let config: ScriptConfig
    public let transaction: BitcoinTransaction
    public let prevouts: [TransactionOutput]
    public private(set) var sigVersion: SigVersion

    // Internal state
    public internal(set) var inputIndex: Int {
        didSet {
            reset()
        }
    }

     /// BIP341
    private(set) var tapLeafHash = Data?.none
    private(set) var leafVersion = UInt8?.none
    let keyVersion: UInt8? = 0

    public private(set) var script: BitcoinScript = .empty
    public internal(set) var stack: [Data] = []

    public private(set) var programCounter = 0
    public private(set) var operationIndex = 0
    public internal(set) var nonPushOperations = 0

    /// BIP342: Tapscript signature operations budget.
    /// Sigops limit The sigops in tapscripts do not count towards the block-wide limit of 80000 (weighted). Instead, there is a per-script sigops budget. The budget equals 50 + the total serialized size in bytes of the transaction input's witness (including the CompactSize prefix). Executing a signature opcode (OP_CHECKSIG, OP_CHECKSIGVERIFY, or OP_CHECKSIGADD) with a non-empty signature decrements the budget by 50. If that brings the budget below zero, the script fails immediately. Signature opcodes with unknown public key type and non-empty signature are also counted.
    var sigopBudget = 0

    /// Support for `OP_CHECKSIG` and `OP_CHECKSIGVERIFY`.
    var lastCodeSeparatorOffset = Int?.none

    /// BIP342
    var lastCodeSeparatorIndex = Int?.none

    /// Support for `OP_TOALTSTACK` and `OP_FROMALTSTACK`.
    var altStack = [Data]()

    /// Support for `OP_IF`, `OP_NOTIF`, `OP_ELSE` and `OP_ENDIF`.
    var pendingIfOperations = [Bool?]()
    var pendingElseOperations = 0

    /// We keep the sighash cache instance inbetween resets / runs / input index updates.
    var sighashCache = SighashCache()

    var prevout: TransactionOutput {
        prevouts[inputIndex]
    }

    var currentOp: ScriptOperation {
        script.operations[operationIndex]
    }

    /// Support for `OP_IF`, `OP_NOTIF`, `OP_ELSE` and `OP_ENDIF`.
    var evaluateBranch: Bool {
        guard let lastEvaluatedIfResult = pendingIfOperations.last(where: { $0 != .none }), let lastEvaluatedIfResult else {
            return true
        }
        return lastEvaluatedIfResult
    }

    /// BIP143
    var segwitScriptCode: Data {
        var scriptData = script.data
        // if the witnessScript contains any OP_CODESEPARATOR, the scriptCode is the witnessScript but removing everything up to and including the last executed OP_CODESEPARATOR before the signature checking opcode being executed, serialized as scripts inside CTxOut.
        if let codesepOffset = lastCodeSeparatorOffset {
            scriptData.removeFirst(codesepOffset + 1)
        }
        return scriptData
    }

    /// BIP342
    var codeSeparatorPosition: UInt32 {
        // https://bitcoin.stackexchange.com/questions/115695/what-are-the-last-bytes-for-in-a-taproot-script-path-sighash
        if let index = lastCodeSeparatorIndex { UInt32(index) } else { UInt32(0xffffffff) }
    }

    /// Evaluates the script with a new stack. All previous mutable state is reset.
    public mutating func run(_ newScript: BitcoinScript, stack newStack: [Data] = [], sigVersion newSigVersion: SigVersion? = .none, leafVersion: UInt8? = .none, tapLeafHash: Data? = .none) throws {

        reset()
        script = newScript
        stack = newStack
        if let newSigVersion {
            sigVersion = newSigVersion
        }
        self.leafVersion = leafVersion
        self.tapLeafHash = tapLeafHash

        if sigVersion == .witnessV1 {
            if let witness = transaction.inputs[inputIndex].witness {
                sigopBudget = BitcoinScript.sigopBudgetBase + witness.size
            } else {
                sigopBudget = BitcoinScript.sigopBudgetBase
            }
        }

        // BIP141
        if (sigVersion == .base || sigVersion == .witnessV0) && script.size > BitcoinScript.maxScriptSize {
            throw ScriptError.scriptSizeLimitExceeded
        }

        // BIP342: Stack + altstack element count limit The existing limit of 1000 elements in the stack and altstack together after every executed opcode remains. It is extended to also apply to the size of initial stack.
        if (sigVersion != .base && sigVersion != .witnessV0) && stack.count > BitcoinScript.maxStackElements {
            throw ScriptError.initialStackLimitExceeded
        }

        // BIP141: The witnessScript is deserialized, and executed after normal script evaluation with the remaining witness stack (≤ 520 bytes for each stack item).
        // BIP342: Stack element size limit The existing limit of maximum 520 bytes per stack element remains, both in the initial stack and in push opcodes.
        guard sigVersion == .base || stack.allSatisfy({ $0.count <= BitcoinScript.maxStackElementSize }) else {
            throw ScriptError.initialStackMaxElementSizeExceeded
        }

        // BIP342: `OP_SUCCESS`
        if sigVersion != .base && sigVersion != .witnessV0 &&
            script.operations.contains(where: { if case .success(_) = $0 { true } else { false }}) {
            if config.contains(.discourageOpSuccess) {
                throw ScriptError.disallowedOpSuccess
            }
            return // Do not run the script.
        }

        for operation in script.operations {
            if (sigVersion == .base || sigVersion == .witnessV0) && !operation.isPush && operation != .success(80) { // .success(80) == .reserved for base and witnessV0
                nonPushOperations += 1
                guard nonPushOperations <= BitcoinScript.maxOperations else {
                    throw ScriptError.operationsLimitExceeded
                }
            }

            // Execute the operation.
            try execute(operation)

            // BIP141
            // BIP342: Stack + altstack element count limit The existing limit of 1000 elements in the stack and altstack together after every executed opcode remains.
            if sigVersion != .base && stack.count + altStack.count > BitcoinScript.maxStackElements {
                throw ScriptError.stacksLimitExceeded
            }
            programCounter += operation.size
            operationIndex += 1
        }
        guard pendingIfOperations.isEmpty, pendingElseOperations == 0 else {
            throw ScriptError.malformedIfElseEndIf
        }
    }

    /// Except stack, cache and input index
    private mutating func reset() {
        let copy = ScriptContext(config, transaction: transaction, prevouts: prevouts)
        programCounter = copy.programCounter
        operationIndex = copy.operationIndex
        nonPushOperations = copy.nonPushOperations
        sigopBudget = copy.sigopBudget
        lastCodeSeparatorOffset = copy.lastCodeSeparatorOffset
        lastCodeSeparatorIndex = copy.lastCodeSeparatorIndex
        altStack = copy.altStack
        pendingIfOperations = copy.pendingIfOperations
        pendingElseOperations = copy.pendingElseOperations
    }

    /// Support for `OP_CHECKSIG` and `OP_CHECKSIGVERIFY`. Legacy scripts only.
    func getScriptCode(signatures: [Data]) throws -> Data {
        precondition(sigVersion == .base)
        var scriptData = script.data
        if let codesepOffset = lastCodeSeparatorOffset {
            scriptData.removeFirst(codesepOffset + 1)
        }

        var scriptCode = Data()
        var programCounter2 = scriptData.startIndex
        while programCounter2 < scriptData.endIndex {
            guard let operation = ScriptOperation(scriptData[programCounter2...]) else {
                preconditionFailure()
                // TODO: What happens to scriptCode if script cannot be fully decoded?
            }

            var operationContainsSignature = false
            for sig in signatures {
                if !sig.isEmpty, operation == .pushBytes(sig) {
                    operationContainsSignature = true
                    if config.contains(.constantScriptCode) {
                        throw ScriptError.nonConstantScript
                    }
                    break
                }
            }

            if
                operation != .codeSeparator && !operationContainsSignature // Equivalent to FindAndDelete
            {
                scriptCode.append(operation.data)
            }
            programCounter2 += operation.size
        }
        return scriptCode
    }

    /// BIP342
    mutating func checkSigopBudget() throws {
        sigopBudget -= BitcoinScript.sigopBudgetDecrement
        if sigopBudget < 0 { throw ScriptError.sigopBudgetExceeded }
    }

    // TODO: A public version of this method should check limits as run() does.
    private mutating func execute(_ op: ScriptOperation) throws {
        op.operationPreconditions()

        // If branch consideration
        if !evaluateBranch {
            switch op {
            case .if, .notIf, .else, .endIf, .verIf, .verNotIf, .codeSeparator, .success(_):
                break
            default: return
            }
        }

        switch op {
        case .zero: opConstant(0)
        case .pushBytes(let d), .pushData1(let d), .pushData2(let d), .pushData4(let d): try opPushBytes(data: d)
        case .oneNegate: op1Negate()
        case .success(_): if sigVersion == .base || sigVersion == .witnessV0 {
            if op.opCode == 80 || op.opCode == 98 || op.opCode == 137 || op.opCode == 138 {
                throw ScriptError.disabledOperation
            } else {
                throw ScriptError.unknownOperation
            }
        } else { preconditionFailure() }
        case .constant(let k): opConstant(k)
        case .noOp: break
        case .if: try opIf()
        case .notIf: try opIf(isNotIf: true)
        case .verIf, .verNotIf: throw ScriptError.disabledOperation
        case .else: try opElse()
        case .endIf: try opEndIf()
        case .verify: try opVerify()
        case .return: throw ScriptError.disabledOperation
        case .toAltStack: try opToAltStack()
        case .fromAltStack: try opFromAltStack()
        case .twoDrop: try op2Drop()
        case .twoDup: try op2Dup()
        case .threeDup: try op3Dup()
        case .twoOver: try op2Over()
        case .twoRot: try op2Rot()
        case .twoSwap: try op2Swap()
        case .ifDup: try opIfDup()
        case .depth: try opDepth()
        case .drop: try opDrop()
        case .dup: try opDup()
        case .nip: try opNip()
        case .over: try opOver()
        case .pick: try opPick()
        case .roll: try opRoll()
        case .rot: try opRot()
        case .swap: try opSwap()
        case .tuck: try opTuck()
        case .cat: throw ScriptError.disabledOperation
        case .subStr: throw ScriptError.disabledOperation
        case .left: throw ScriptError.disabledOperation
        case .right: throw ScriptError.disabledOperation
        case .size: try opSize()
        case .invert: throw ScriptError.disabledOperation
        case .and: throw ScriptError.disabledOperation
        case .or: throw ScriptError.disabledOperation
        case .xor: throw ScriptError.disabledOperation
        case .equal: try opEqual()
        case .equalVerify: try opEqualVerify()
        case .oneAdd: try op1Add()
        case .oneSub:  try op1Sub()
        case .twoMul: throw ScriptError.disabledOperation
        case .twoDiv: throw ScriptError.disabledOperation
        case .negate: try opNegate()
        case .abs: try opAbs()
        case .not: try opNot()
        case .zeroNotEqual: try op0NotEqual()
        case .add: try opAdd()
        case .sub: try opSub()
        case .mul: throw ScriptError.disabledOperation
        case .div: throw ScriptError.disabledOperation
        case .mod: throw ScriptError.disabledOperation
        case .lShift: throw ScriptError.disabledOperation
        case .rShift: throw ScriptError.disabledOperation
        case .boolAnd: try opBoolAnd()
        case .boolOr: try opBoolOr()
        case .numEqual: try opNumEqual()
        case .numEqualVerify: try opNumEqualVerify()
        case .numNotEqual: try opNumNotEqual()
        case .lessThan: try opLessThan()
        case .greaterThan: try opGreaterThan()
        case .lessThanOrEqual: try opLessThanOrEqual()
        case .greaterThanOrEqual: try opGreaterThanOrEqual()
        case .min: try opMin()
        case .max: try opMax()
        case .within: try opWithin()
        case .ripemd160: try opRIPEMD160()
        case .sha1: try opSHA1()
        case .sha256: try opSHA256()
        case .hash160: try opHash160()
        case .hash256: try opHash256()
        case .codeSeparator: try opCodeSeparator()
        case .checkSig: try opCheckSig()
        case .checkSigVerify: try opCheckSigVerify()
        case .checkMultiSig:
            guard sigVersion == .base || sigVersion == .witnessV0 else { throw ScriptError.tapscriptCheckMultiSigDisabled }
            try opCheckMultiSig()
        case .checkMultiSigVerify:
            guard sigVersion == .base || sigVersion == .witnessV0 else { throw ScriptError.tapscriptCheckMultiSigDisabled }
            try opCheckMultiSigVerify()
        case .noOp1: if config.contains(.discourageUpgradableNoOps) { throw ScriptError.disallowedNoOp }
        case .checkLockTimeVerify:
            guard config.contains(.checkLockTimeVerify) else { break }
            try opCheckLockTimeVerify()
        case .checkSequenceVerify:
            guard config.contains(.checkSequenceVerify) else { break }
            try opCheckSequenceVerify()
        case .noOp4, .noOp5, .noOp6, .noOp7, .noOp8, .noOp9, .noOp10: if config.contains(.discourageUpgradableNoOps) { throw ScriptError.disallowedNoOp }
        case .checkSigAdd:
            guard sigVersion == .witnessV1 else { throw ScriptError.unknownOperation }
            try opCheckSigAdd()
        case .unknown(_): throw ScriptError.unknownOperation
        case .pubKeyHash: throw ScriptError.disabledOperation
        case .pubKey:  throw ScriptError.disabledOperation
        case .invalidOpCode: throw ScriptError.disabledOperation
        }
    }

    mutating func getUnaryNumericParam() throws -> ScriptNumber {
        let first = try getUnaryParam()
        let minimal = config.contains(.minimalData)
        let a = try ScriptNumber(first, minimal: minimal)
        return a
    }

    mutating func getUnaryParam(keep: Bool = false) throws -> Data {
        guard let param = stack.last else {
            throw ScriptError.missingStackArgument
        }
        if !keep { stack.removeLast() }
        return param
    }

    mutating func getBinaryNumericParams() throws -> (ScriptNumber, ScriptNumber) {
        let (first, second) = try getBinaryParams()
        let minimal = config.contains(.minimalData)
        let a = try ScriptNumber(first, minimal: minimal)
        let b = try ScriptNumber(second, minimal: minimal)
        return (a, b)
    }

    mutating func getBinaryParams() throws -> (Data, Data) {
        guard stack.count > 1 else {
            throw ScriptError.missingStackArgument
        }
        let second = stack.removeLast()
        let first = stack.removeLast()
        return (first, second)
    }

    mutating func getTernaryNumericParams() throws -> (ScriptNumber, ScriptNumber, ScriptNumber) {
        let (first, second, third) = try getTernaryParams()
        let minimal = config.contains(.minimalData)
        let a = try ScriptNumber(first, minimal: minimal)
        let b = try ScriptNumber(second, minimal: minimal)
        let c = try ScriptNumber(third, minimal: minimal)
        return (a, b, c)
    }

    mutating func getTernaryParams() throws -> (Data, Data, Data) {
        guard stack.count > 2 else {
            throw ScriptError.missingStackArgument
        }
        let third = stack.removeLast()
        let (first, second) = try getBinaryParams()
        return (first, second, third)
    }

    mutating func getQuaternaryParams() throws -> (Data, Data, Data, Data) {
        guard stack.count > 3 else {
            throw ScriptError.missingStackArgument
        }
        let fourth = stack.removeLast()
        let (first, second, third) = try getTernaryParams()
        return (first, second, third, fourth)
    }

    mutating func getSenaryParams() throws -> (Data, Data, Data, Data, Data, Data) {
        guard stack.count > 5 else {
            throw ScriptError.missingStackArgument
        }
        let sixth = stack.removeLast()
        let fifth = stack.removeLast()
        let (first, second, third, fourth) = try getQuaternaryParams()
        return (first, second, third, fourth, fifth, sixth)
    }
}
