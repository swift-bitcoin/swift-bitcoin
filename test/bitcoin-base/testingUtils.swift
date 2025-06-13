import Foundation
@testable import BitcoinBase
extension Transaction {
    static let empty = Self(version: .v1, locktime: .init(0), ins: [], outs: [])
}

extension Script {
    func run(_ stack: inout [Data], sigVersion: SigVersion = .base) throws {
        var context = ScriptRuntime(.standard, tx: .empty, input: -1, prevouts: [])
        try context.run(self, stack: stack, sigVersion: sigVersion)
        stack = context.stack
    }

    func runV1(_ stack: inout [Data]) throws {
        let config = ScriptConfig.standard.subtracting(.discourageOpSuccess)
        var context = ScriptRuntime(config, tx: .init(version: .v1, locktime: .init(0), ins: [.init(outpoint: .coinbase, witness: .init([]))], outs: []), input: 0, prevouts: [])
        try context.run(self, stack: stack, sigVersion: .witnessV1)
        stack = context.stack
    }
}

extension Array where Element == Data {
    static func withConstants(_ constants: [Int]) -> Self {
        constants.compactMap {
            (try? ScriptNumber($0))?.binaryData ?? .none
        }
    }

    static func withConstants(_ constants: Int...) -> Self {
        withConstants(constants)
    }
}
