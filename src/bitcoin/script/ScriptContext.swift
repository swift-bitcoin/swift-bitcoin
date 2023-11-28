import Foundation

/// SCRIPT execution context.
struct ScriptContext {

    init(transaction: Transaction, inputIndex: Int, previousOutputs: [Output], version: ScriptVersion, configuration: ScriptConfigurarion, script: Script, decodedOperations: [ScriptOperation] = [ScriptOperation](), operationIndex: Int = 0, programCounter: Int = 0, sigopBudget: Int = 0, lastCodeSeparatorOffset: Int? = .none, altStack: [Data] = [], pendingIfOperations: [Bool?] = [Bool?](), pendingElseOperations: Int = 0, lastCodeSeparatorIndex: Int? = .none, succeedUnconditionally: Bool = false, tapLeafHash: Data? = nil) {
        self.transaction = transaction
        self.inputIndex = inputIndex
        self.previousOutputs = previousOutputs
        self.version = version
        self.configuration = configuration
        self.script = script
        self.decodedOperations = decodedOperations
        self.operationIndex = operationIndex
        self.programCounter = programCounter
        self.sigopBudget = if version == .witnessV1 {
            if let witness = transaction.inputs[inputIndex].witness {
                50 + witness.size
            } else { preconditionFailure() }
        } else { 0 }
        self.lastCodeSeparatorOffset = lastCodeSeparatorOffset
        self.altStack = altStack
        self.pendingIfOperations = pendingIfOperations
        self.pendingElseOperations = pendingElseOperations
        self.lastCodeSeparatorIndex = lastCodeSeparatorIndex
        self.succeedUnconditionally = succeedUnconditionally
        self.tapLeafHash = tapLeafHash
    }
    
    let transaction: Transaction
    let inputIndex: Int
    let previousOutputs: [Output]
    let version: ScriptVersion
    let configuration: ScriptConfigurarion
    let script: Script
    var decodedOperations = [ScriptOperation]()
    var operationIndex = 0
    var programCounter = 0
    var nonPushOperations = 0

    /// BIP342: Tapscript signature operations budget.
    /// Sigops limit The sigops in tapscripts do not count towards the block-wide limit of 80000 (weighted). Instead, there is a per-script sigops budget. The budget equals 50 + the total serialized size in bytes of the transaction input's witness (including the CompactSize prefix). Executing a signature opcode (OP_CHECKSIG, OP_CHECKSIGVERIFY, or OP_CHECKSIGADD) with a non-empty signature decrements the budget by 50. If that brings the budget below zero, the script fails immediately. Signature opcodes with unknown public key type and non-empty signature are also counted.
    var sigopBudget = 0

    var previousOutput: Output {
        previousOutputs[inputIndex]
    }

    /// Support for `OP_CHECKSIG` and `OP_CHECKSIGVERIFY`.
    var lastCodeSeparatorOffset: Int? = .none

    /// Support for `OP_TOALTSTACK` and `OP_FROMALTSTACK`.
    var altStack: [Data] = []

    /// Support for `OP_IF`, `OP_NOTIF`, `OP_ELSE` and `OP_ENDIF`.
    var pendingIfOperations = [Bool?]()
    var pendingElseOperations = 0

    /// BIP342
    var lastCodeSeparatorIndex: Int? = .none
    private(set) var succeedUnconditionally = false

    /// BIP341
    let tapLeafHash: Data?
    let keyVersion: UInt8? = 0

    /// Support for `OP_IF`, `OP_NOTIF`, `OP_ELSE` and `OP_ENDIF`.
    var evaluateBranch: Bool {
        guard let lastEvaluatedIfResult = pendingIfOperations.last(where: { $0 != .none }), let lastEvaluatedIfResult else {
            return true
        }
        return lastEvaluatedIfResult
    }

    /// Support for `OP_CHECKSIG` and `OP_CHECKSIGVERIFY`. Legacy scripts only.
    func getScriptCode(signatures: [Data]) throws -> Data {
        precondition(version == .base)
        var scriptData = script.data
        if let codesepOffset = lastCodeSeparatorOffset {
            scriptData.removeFirst(codesepOffset + 1)
        }

        var scriptCode = Data()
        var programCounter2 = scriptData.startIndex
        while programCounter2 < scriptData.endIndex {
            guard let operation = ScriptOperation(scriptData[programCounter2...], version: version) else {
                preconditionFailure()
                // TODO: What happens to scriptCode if script cannot be fully decoded?
            }

            var operationContainsSignature = false
            for sig in signatures {
                if !sig.isEmpty, operation == .pushBytes(sig) {
                    operationContainsSignature = true
                    if configuration.constantScriptCode {
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

    /// BIP342
    mutating func setSucceedUnconditionally() {
        if !succeedUnconditionally {
            succeedUnconditionally.toggle()
        }
    }

    /// BIP342
    mutating func checkSigopBudget() throws {
        sigopBudget -= 50
        if sigopBudget < 0 { throw ScriptError.sigopBudgetExceeded }
    }
}
