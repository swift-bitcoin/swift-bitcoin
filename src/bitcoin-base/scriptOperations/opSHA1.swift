import Foundation
import BitcoinCrypto

/// The input is hashed using SHA-1.
func opSHA1(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    stack.append(Data(SHA1.hash(data: first)))
}
