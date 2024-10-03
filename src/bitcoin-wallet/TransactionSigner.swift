import BitcoinBase
import BitcoinCrypto

public class TransactionSigner {

    public init(transaction: BitcoinTransaction, prevouts: [TransactionOutput]) {
        self.transaction = transaction
        hasher = .init(transaction: transaction, prevouts: prevouts, sighashType: .all)
    }

    public init(transaction: BitcoinTransaction, prevouts: [TransactionOutput], sighashType: SighashType? = Optional.none) {
        self.transaction = transaction
        hasher = .init(transaction: transaction, prevouts: prevouts, sighashType: sighashType)
    }

    public private(set) var transaction: BitcoinTransaction
    private let hasher: SignatureHash

    public var sighashType: SighashType? {
        get { hasher.sighashType }
        set { hasher.sighashType = newValue }
    }


    @discardableResult
    public func sign(input inputIndex: Int, with secretKey: SecretKey) -> BitcoinTransaction {
        let lockScript = hasher.prevouts[inputIndex].script
        if lockScript.isPayToPublicKey || lockScript.isPayToPublicKeyHash || lockScript.isPayToWitnessKeyHash || lockScript.isPayToTaproot {

            let sigVersion: SigVersion = if lockScript.isPayToWitnessKeyHash { .witnessV0 }
                             else if lockScript.isPayToTaproot { .witnessV1 }
                             else { .base }

            hasher.set(input: inputIndex, sigVersion: sigVersion)
            let sighash = hasher.value

            guard let signature = if lockScript.isPayToTaproot {
                secretKey.taprootSecretKey().sign(hash: sighash, signatureType: .schnorr)
            } else {
                secretKey.sign(hash: sighash)
            } else { preconditionFailure() }

            let signatureExt = ExtendedSignature(signature, hasher.sighashType)
            // For pay-to-public key we just need to sign the hash and add the signature to the input's unlock script.
            var witnessData = [signatureExt.data]
            if lockScript.isPayToPublicKeyHash || lockScript.isPayToWitnessKeyHash {
                // For pay-to-public-key-hash we need to also add the public key to the unlock script.
                witnessData.append(secretKey.publicKey.data)
            }
            if lockScript.isPayToWitnessKeyHash || lockScript.isPayToTaproot {
                // For pay-to-witness-public-key-hash we sign a different hash and we add the signature and public key to the input's _witness_.
                transaction = transaction.withWitness(witnessData, input: inputIndex)
            } else {
                let ops = witnessData.map { ScriptOperation.pushBytes($0) }
                transaction = transaction.withUnlockScript(.init(ops), input: inputIndex)
            }
        } else {
            fatalError("Other output types not yet implemented")
        }
        return transaction
    }
}
