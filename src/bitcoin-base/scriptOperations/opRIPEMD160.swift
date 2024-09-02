import Foundation
import BitcoinCrypto

/// The input is hashed using RIPEMD-160.
func opRIPEMD160(_ stack: inout [Data]) throws {
    let first = try getUnaryParam(&stack)
    stack.append(Data(RIPEMD160.hash(data: first)))
}
