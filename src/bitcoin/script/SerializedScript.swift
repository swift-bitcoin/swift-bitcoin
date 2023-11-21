import Foundation

/// A bitcoin script that hasn't been decoded yet. It may contain invalid operation codes and data as it's backed by a byte array.  For a representation of a ``Script`` that is backed by a list of valid operations  see ``ParsedScript``.
public struct SerializedScript: Script {

    public static let empty = Self(.init())
    private(set) public var data: Data
    public let version: ScriptVersion

    public init(_ data: Data, version: ScriptVersion = .legacy) {
        self.data = data
        self.version = version
    }

    init?(prefixedData: Data, version: ScriptVersion = .legacy) {
        guard let data = Data(varLenData: prefixedData) else {
            return nil
        }
        self.init(data, version: version)
    }

    /// Attempts to parse the script and return its assembly representation. Otherwise returns an empty string.
    public var asm: String {
        // TODO: When error attempt to return partial decoding. Check how core does this.
        parsed?.asm ?? ""
    }

    public var size: Int {
       data.count
    }

    public var isEmpty: Bool {
        data.isEmpty
    }

    public var parsed: ParsedScript? {
        ParsedScript(data, version: version)
    }

    public var serialized: SerializedScript { self }

    public func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output], tapLeafHash: Data? = .none, configuration: ScriptConfigurarion) throws {
        var context = ScriptContext(transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, configuration: configuration, script: self, tapLeafHash: tapLeafHash)

        while context.programCounter < data.count {
            let startIndex = data.startIndex + context.programCounter
            guard let operation = ScriptOperation(data[startIndex...], version: version) else {
                throw ScriptError.invalidInstruction
            }
            context.decodedOperations.append(operation)
            try operation.execute(stack: &stack, context: &context)

            // BIP342: OP_SUCCESS
            if context.succeedUnconditionally { return }

            context.programCounter += operation.size
        }
        guard context.pendingIfOperations.isEmpty, context.pendingElseOperations == 0 else {
            throw ScriptError.invalidScript
        }
    }
}
