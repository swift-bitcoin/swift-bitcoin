import Foundation
import BitcoinCrypto

public func calculateMerkleRoot(_ txs: [Transaction]) -> Data {
    calculateMerkleRoot(txs.map(\.id))
}

public func calculateMerkleRoot(_ hashes: [Data]) -> Data {
    precondition(!hashes.isEmpty)
    if hashes.count == 1 {
        return hashes[0]
    }
    let hashes = if hashes.count % 2 == 1 {
        hashes + [hashes[hashes.endIndex - 1]]
    } else {
        hashes
    }
    var nextHashes = [Data]()
    for i in stride(from: hashes.startIndex, to: hashes.endIndex, by: 2) {
        nextHashes.append(Data(Hash256.hash(data: hashes[i] + hashes[i + 1])))
    }
    return calculateMerkleRoot(nextHashes)
}

public func calculateWitnessMerkleRoot(_ txs: [Transaction], addCoinbaseID: Bool = false) -> Data {
    calculateMerkleRoot(
        (addCoinbaseID ? [Transaction.coinbaseWitnessID] : []) +
        txs.map(\.witnessID))
}
