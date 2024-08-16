import Foundation
import BitcoinCrypto
import BitcoinBase

func calculateWitnessMerkleRoot(_ transactions: [BitcoinTransaction]) -> Data {
    calculateMerkleRoot(
        [BitcoinTransaction.coinbaseWitnessIdentifier] +
        transactions.map(\.witnessIdentifier))
}
