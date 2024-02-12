import Foundation
@testable import Bitcoin

extension BitcoinTransaction {
    static let empty = Self(version: .v1, locktime: .init(0), inputs: [], outputs: [])
}

extension BitcoinScript {
    func run(_ stack: inout [Data]) throws {
        try run(&stack, transaction: .empty, inputIndex: -1, previousOutputs: [], configuration: .standard)
    }

    func runV1(_ stack: inout [Data]) throws {
        let configuration = ScriptConfigurarion(discourageOpSuccess: false)
        try run(&stack, transaction: .init(version: .v1, locktime: .init(0), inputs: [.init(outpoint: .coinbase, sequence: .final, script: .empty, witness: .init([]))], outputs: []), inputIndex: 0, previousOutputs: [], configuration: configuration)
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
