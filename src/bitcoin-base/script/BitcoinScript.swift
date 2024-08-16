import Foundation

/// A fully decoded Bitcoin script and its associated signature version.
///
/// If there is a portion of the data that cannot be parsed it will be stored in ``BitcoinScript/unparsable``.
public struct BitcoinScript: Equatable, Sendable {

    // MARK: - Initializers
    
    /// Creates a script from a list of operations.
    /// - Parameters:
    ///   - operations: A sequence of script operations.
    ///   - sigVersion: The signature version to be assumed by this script.
    public init(_ operations: [ScriptOperation], sigVersion: SigVersion = .base) {
        self.sigVersion = sigVersion
        self.operations = operations
        self.unparsable = .init()
    }

    // MARK: - Instance Properties

    /// The signature version of this script.
    public let sigVersion: SigVersion

    /// List of all decoded script operations.
    public let operations: [ScriptOperation]

    /// The portion of the original script data that could not be decoded into operations.
    public let unparsable: Data

    // MARK: - Computed Properties

    /// Attempts to parse the script and return its assembly representation. Otherwise returns an empty string.
    public var asm: String {
        (operations.map(\.asm) + [unparsable.hex]).joined(separator: " ")
    }

    var isEmpty: Bool {
        operations.isEmpty && unparsable.isEmpty
    }

    // BIP16
    var isPayToScriptHash: Bool {
        if size == 23,
           operations.count == 3,
           operations[0] == .hash160,
           case .pushBytes(_) = operations[1],
           operations[2] == .equal { true } else { false }
    }

    /// BIP141
    var isSegwit: Bool {
        if size >= 3 && size <= 41,
           operations.count == 2,
           case .pushBytes(_) = operations[1]
        {
            if case .constant(_) = operations[0] { true } else { operations[0] == .zero }
        } else {
            false
        }
    }

    /// BIP141
    var witnessProgram: Data {
        precondition(isSegwit)
        guard case let .pushBytes(data) = operations[1] else {
            preconditionFailure()
        }
        return data
    }

    /// BIP141
    var witnessVersion: Int {
        precondition(isSegwit)
        return if case let .constant(value) = operations[0] { Int(value) } else if operations[0] == .zero { 0 } else { preconditionFailure() }
    }

    // MARK: - Instance Methods

    /// Evaluates the script.
    public func run(_ stack: inout [Data], transaction: BitcoinTransaction, inputIndex: Int, previousOutputs: [TransactionOutput], tapLeafHash: Data?, config: ScriptConfig) throws {

        // BIP141
        if (sigVersion == .base || sigVersion == .witnessV0) && size > Self.maxScriptSize {
            throw ScriptError.scriptSizeLimitExceeded
        }

        // BIP342: Stack + altstack element count limit The existing limit of 1000 elements in the stack and altstack together after every executed opcode remains. It is extended to also apply to the size of initial stack.
        if (sigVersion != .base && sigVersion != .witnessV0) && stack.count > Self.maxStackElements {
            throw ScriptError.initialStackLimitExceeded
        }

        // BIP141: The witnessScript is deserialized, and executed after normal script evaluation with the remaining witness stack (≤ 520 bytes for each stack item).
        // BIP342: Stack element size limit The existing limit of maximum 520 bytes per stack element remains, both in the initial stack and in push opcodes.
        guard sigVersion == .base || stack.allSatisfy({ $0.count <= Self.maxStackElementSize }) else {
            throw ScriptError.initialStackMaxElementSizeExceeded
        }

        var context = ScriptContext(transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, config: config, script: self, tapLeafHash: tapLeafHash)

        // BIP342: `OP_SUCCESS`
        if sigVersion != .base && sigVersion != .witnessV0 &&
           operations.contains(where: { if case .success(_) = $0 { true } else { false }}) {
            if config.contains(.discourageOpSuccess) {
                throw ScriptError.disallowedOpSuccess
            }
            return // Do not run the script.
        }


        for operation in operations {
            if (sigVersion == .base || sigVersion == .witnessV0) && !operation.isPush && operation != .reserved(80) {
                context.nonPushOperations += 1
                guard context.nonPushOperations <= Self.maxOperations else {
                    throw ScriptError.operationsLimitExceeded
                }
            }

            try operation.execute(stack: &stack, context: &context)

            // BIP141
            // BIP342: Stack + altstack element count limit The existing limit of 1000 elements in the stack and altstack together after every executed opcode remains.
            if sigVersion != .base && stack.count + context.altStack.count > Self.maxStackElements {
                throw ScriptError.stacksLimitExceeded
            }
            context.programCounter += operation.size
            context.operationIndex += 1
        }
        guard context.pendingIfOperations.isEmpty, context.pendingElseOperations == 0 else {
            throw ScriptError.malformedIfElseEndIf
        }
    }

    public func run(_ stack: inout [Data], transaction: BitcoinTransaction, inputIndex: Int, previousOutputs: [TransactionOutput], config: ScriptConfig) throws {
        try run(&stack, transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, tapLeafHash: .none, config: config)
    }

    // BIP62
    func checkPushOnly() throws {
        guard operations.allSatisfy(\.isPush), unparsable.isEmpty else {
            throw ScriptError.nonPushOnlyScript
        }
    }

    // MARK: - Type Properties

    public static let empty = Self([])

    /// Maximum number of public keys per multisig.
    static let maxMultiSigPublicKeys = 20

    /// Maximum number of non-push operations per script.
    static let maxOperations = 201

    /// Maximum script length in bytes.
    static let maxScriptSize = 10_000

    /// BIP342
    static let maxStackElementSize = 520
    static let sigopBudgetBase = 50
    static let sigopBudgetDecrement = 50

    /// BIP342
    private static let maxStackElements = 1_000

    // MARK: - Type Methods

    // No type methods yet.

}

extension BitcoinScript: ExpressibleByArrayLiteral {

    public init(arrayLiteral operations: ScriptOperation...) {
        self.init(operations)
    }
}
