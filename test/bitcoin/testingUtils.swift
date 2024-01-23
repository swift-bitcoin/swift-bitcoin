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

// - MARK: Hexadecimal encoding/decoding

extension Data {

    /// Create instance from string containing hex digits.
    init?(hex: String) {
        guard let regex = try? NSRegularExpression(pattern: "([0-9a-fA-F]{2})", options: []) else {
            return nil
        }
        let range = NSRange(location: 0, length: hex.count)
        let bytes = regex.matches(in: hex, options: [], range: range)
            .compactMap { Range($0.range(at: 1), in: hex) }
            .compactMap { UInt8(hex[$0], radix: 16) }
        self.init(bytes)
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
