import Foundation
import BitcoinCrypto
import BitcoinBase

func calculateMerkleRoot(_ transactions: [BitcoinTransaction]) -> Data {
    calculateMerkleRoot(transactions.map(\.id))
}

func calculateMerkleRoot(_ hashes: [Data]) -> Data {
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
