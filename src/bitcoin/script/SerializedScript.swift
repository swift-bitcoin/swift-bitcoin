import Foundation

/// A bitcoin script that hasn't been decoded yet. It may contain invalid operation codes and data.
public struct SerializedScript: Script {

    public static let empty = Self(.init())
    private(set) public var data: Data
    public let version: ScriptVersion

    init(_ data: Data, version: ScriptVersion = .legacy) {
        self.data = data
        self.version = version
    }

    init?(prefixedData: Data, version: ScriptVersion = .legacy) {
        guard let data = Data(varLenData: prefixedData) else {
            return nil
        }
        self.init(data, version: version)
    }

    public var size: Int {
       data.count
    }

    public var asm: String {
        "" // TODO: convert to decoded script and call its asm method
    }

    public var isEmpty: Bool {
        data.isEmpty
    }

    public func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output]) throws {
        var context = ScriptContext(transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, script: self)

        while context.programCounter < data.count {
            let startIndex = data.startIndex + context.programCounter
            guard let operation = ScriptOperation(data[startIndex...], version: version) else {
                throw ScriptError.invalidInstruction
            }

            context.decodedOperations.append(operation)
            context.programCounter += operation.size

            try operation.execute(stack: &stack, context: &context)
        }
        if let last = stack.last, !ScriptBoolean(last).value {
            throw ScriptError.invalidScript
        }
    }
}
