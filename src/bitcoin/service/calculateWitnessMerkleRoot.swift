import Foundation
import BitcoinCrypto

func calculateWitnessMerkleRoot(_ transactions: [BitcoinTransaction]) -> Data {
    calculateMerkleRoot(
        [BitcoinTransaction.coinbaseWitnessIdentifier] +
        transactions.map(\.witnessIdentifier))
}
