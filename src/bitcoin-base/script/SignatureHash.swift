import Foundation
import BitcoinCrypto

/// Aka `sigMsg`. See https://en.bitcoin.it/wiki/OP_CHECKSIG
public struct SignatureHash: Equatable, Sendable {

    public init(tx: Transaction, input: Int, sighashType: SighashType, scriptCode: Data) {

        if sighashType.isSingle && input >= tx.outs.count {
            // Note: The transaction that uses SIGHASH_SINGLE type of signature should not have more inputs than outputs. However if it does (because of the pre-existing implementation), it shall not be rejected, but instead for every "illegal" input (meaning: an input that has an index bigger than the maximum output index) the node should still verify it, though assuming the hash of 0000000000000000000000000000000000000000000000000000000000000001
            //
            // From [https://en.bitcoin.it/wiki/BIP_0143]:
            // In the original algorithm, a uint256 of 0x0000......0001 is committed if the input index for a SINGLE signature is greater than or equal to the number of outputs.
            data = Data([0x01]) + Data(repeating: 0, count: 31)
            return
        }
        let message = SignatureMessage(tx: tx, input: input, sighashType: sighashType, scriptCode: scriptCode/* ?? prevout.script.binaryData*/)
        data = Data(Hash256.hash(data: message.data))
    }

    public let data: Data
}
