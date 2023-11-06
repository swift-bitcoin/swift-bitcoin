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

    func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output], configuration: ScriptConfigurarion) throws

    static var empty: Self { get }
}

extension Script {

    public var prefixedData: Data {
        data.varLenData
    }

    public var prefixedSize: Int {
        data.varLenSize
    }

    // BIP16
    var isPayToScriptHash: Bool {
        if size == 23,
           let operations = parsed?.operations,
           operations.count == 3,
           operations[0] == .hash160,
           case .pushBytes(_) = operations[1],
           operations[2] == .equal { true } else { false }
    }

    // BIP62
    func checkPushOnly() throws {
        guard let parsed else {
            throw ScriptError.unparsableScript
        }
        for op in parsed.operations {
            switch op {
            case .oneNegate, .zero, .constant(_), .pushBytes(_), .pushData1(_), .pushData2(_), .pushData4(_): break
            default: throw ScriptError.nonPushOnlyScript
            }
        }
    }
}
