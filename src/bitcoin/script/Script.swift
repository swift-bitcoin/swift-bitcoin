import Foundation

// A generic bitcoin script which can be in its serialized form or parsed.
public protocol Script: Equatable {

    var version: ScriptVersion { get }
    var data: Data { get }
    var size: Int { get }
    var prefixedData: Data { get }
    var prefixedSize: Int { get }

    var asm: String { get }

    static var empty: Self { get }
    var isEmpty: Bool { get }
    func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output]) throws
}

extension Script {

    public var prefixedData: Data {
        data.varLenData
    }

    public var prefixedSize: Int {
        data.varLenSize
    }
}
