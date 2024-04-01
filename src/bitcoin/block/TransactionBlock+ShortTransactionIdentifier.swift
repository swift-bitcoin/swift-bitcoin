import Foundation
import BitcoinCrypto

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
extension TransactionBlock {

    /// Short transaction IDs are used to represent a transaction without sending a full 256-bit hash. They are calculated by:
    ///   1. single-SHA256 hashing the block header with the nonce appended (in little-endian)
    ///   2. Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
    ///   3. Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
    func makeShortTransactionIdentifier(for transactionIndex: Int, nonce: UInt64) -> Data {

        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        let headerData = header.data + Data(value: nonce)
        let headerHash = sha256(headerData)

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let firstInt = headerHash.withUnsafeBytes { $0.load(as: UInt64.self) }
        let secondInt = headerHash.dropFirst(MemoryLayout.size(ofValue: firstInt)).withUnsafeBytes { $0.load(as: UInt64.self) }
        var sipHasher = SipHasher(k0: firstInt, k1: secondInt)

        let transactionID = transactions[transactionIndex].witnessIdentifier
        transactionID.withUnsafeBytes { sipHasher.append($0) }
        let sipHash = sipHasher.finalize()

        // Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
        return Data(value: sipHash).dropLast(2)
    }
}
