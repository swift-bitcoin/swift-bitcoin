import Foundation
import BitcoinCrypto

/// The input is hashed twice: first with SHA-256 and then with RIPEMD-160.
func opHash160(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    stack.append(hash160(first))
}
