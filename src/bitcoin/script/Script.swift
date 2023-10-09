import Foundation

// A generic bitcoin script which can be in its serialized form or parsed.
public protocol Script: Equatable {
    var version: ScriptVersion { get }
    var data: Data { get }
    var size: Int { get }
    var prefixedData: Data { get }
    var prefixedSize: Int { get }
    var asm: String { get }
    var parsed: ParsedScript? { get }
    var serialized: SerializedScript { get }
    var isEmpty: Bool { get }

    func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output]) throws

    static var empty: Self { get }
}

extension Script {

    public var prefixedData: Data {
        data.varLenData
    }

    public var prefixedSize: Int {
        data.varLenSize
    }
}
