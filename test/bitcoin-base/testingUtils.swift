import Foundation
@testable import BitcoinBase
extension BitcoinTx {
    static let empty = Self(version: .v1, locktime: .init(0), ins: [], outs: [])
}

extension BitcoinScript {
    func run(_ stack: inout [Data], sigVersion: SigVersion = .base) throws {
        var context = ScriptContext(.standard, tx: .empty, txIn: -1, prevouts: [])
        try context.run(self, stack: stack, sigVersion: sigVersion)
        stack = context.stack
    }

    func runV1(_ stack: inout [Data]) throws {
        let config = ScriptConfig.standard.subtracting(.discourageOpSuccess)
        var context = ScriptContext(config, tx: .init(version: .v1, locktime: .init(0), ins: [.init(outpoint: .coinbase, witness: .init([]))], outs: []), txIn: 0, prevouts: [])
        try context.run(self, stack: stack, sigVersion: .witnessV1)
        stack = context.stack
    }
}

extension Array where Element == Data {
    static func withConstants(_ constants: [Int]) -> Self {
        constants.compactMap {
            (try? ScriptNum($0))?.binaryData ?? .none
        }
    }

    static func withConstants(_ constants: Int...) -> Self {
        withConstants(constants)
    }
}
