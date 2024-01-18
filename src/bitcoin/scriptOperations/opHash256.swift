import Foundation
import BitcoinCrypto

/// The input is hashed twice with SHA-256.
func opHash256(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    stack.append(hash256(first))
}
