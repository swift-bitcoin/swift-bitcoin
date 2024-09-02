import Foundation
@testable import BitcoinBase
extension BitcoinTransaction {
    static let empty = Self(version: .v1, locktime: .init(0), inputs: [], outputs: [])
}

extension BitcoinScript {
    func run(_ stack: inout [Data]) throws {
        var context = ScriptContext(transaction: .empty, inputIndex: -1, previousOutputs: [], config: .standard)
        try context.run(self, stack: stack)
        stack = context.stack
    }

    func runV1(_ stack: inout [Data]) throws {
        let config = ScriptConfig.standard.subtracting(.discourageOpSuccess)
        var context = ScriptContext(transaction: .init(version: .v1, locktime: .init(0), inputs: [.init(outpoint: .coinbase, sequence: .final, script: .empty, witness: .init([]))], outputs: []), inputIndex: 0, previousOutputs: [], config: config)
        try context.run(self, stack: stack)
        stack = context.stack
    }
}

extension Array where Element == Data {
    static func withConstants(_ constants: [Int]) -> Self {
        constants.compactMap {
            (try? ScriptNumber($0))?.data ?? .none
        }
    }

    static func withConstants(_ constants: Int...) -> Self {
        withConstants(constants)
    }
}
