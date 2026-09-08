import Foundation
import BitcoinCrypto
import BitcoinBase

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
extension Transaction {
    /// Short transaction IDs are used to represent a transaction without sending a full 256-bit hash. They are calculated by:
    ///   1. single-SHA256 hashing the block header with the nonce appended (in little-endian)
    ///   2. Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
    ///   3. Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
    func shortID(nonce: UInt64, first: UInt64, second: UInt64) -> UInt64 {
        var hasher = SipHash(k0: first, k1: second)
        let txID = witnessID
        hasher.update(data: txID)
        let sipHash = hasher.finalize().value

        // Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
        return (sipHash << 16) >> 16
    }
}
