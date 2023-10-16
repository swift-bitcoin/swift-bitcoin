import Foundation

/// A valid script that does not need decoding as it's backed by a list of operations instead of raw data. For a representation of a ``Script`` that is backed by a byte array see ``SerializedScript``.
public struct ParsedScript: Script {

    public static let empty = Self([])
    private(set) public var operations: [ScriptOperation]
    public let version: ScriptVersion

    public init(_ operations: [ScriptOperation], version: ScriptVersion = .legacy) {
        self.operations = operations
        self.version = version
    }

    init?(_ data: Data, version: ScriptVersion = .legacy) {
        var data = data
        self.operations = []
        while data.count > 0 {
            guard let operation = ScriptOperation(data, version: version) else {
                return nil
            }
            operations.append(operation)
            data = data.dropFirst(operation.size)
        }
        self.version = version
    }

    public var data: Data {
        operations.reduce(Data()) { $0 + $1.data }
    }

    public var asm: String {
        operations.reduce("") {
            ($0.isEmpty ? "" : "\($0) ") + $1.asm
        }
    }

    public var size: Int {
        operations.reduce(0) { $0 + $1.size }
    }

    public var prefixedSize: Int {
        UInt64(size).varIntSize + size
    }

    public var isEmpty: Bool {
        operations.isEmpty
    }

    public var parsed: ParsedScript? { self }

    public var serialized: SerializedScript {
        SerializedScript(data, version: version)
    }

    public func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output]) throws {
        var context = ScriptContext(transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, script: self)
        
        for operation in operations {

            /// Support for `OP_CODESEPARATOR` – and indirectly `OP_CHECKSIG` / `OP_CHECKSIGVERIFY`.
            if operation == .codeSeparator {
                context.lastCodeSeparatorOffset = context.programCounter
            }

            context.decodedOperations.append(operation)
            context.programCounter += operation.size
            try operation.execute(stack: &stack, context: &context)
        }
        guard context.pendingIfOperations.isEmpty, context.pendingElseOperations == 0 else {
            throw ScriptError.invalidScript
        }
    }
}
