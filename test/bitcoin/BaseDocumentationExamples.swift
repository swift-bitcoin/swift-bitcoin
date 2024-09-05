import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase

struct BaseDocumentationExamples {

    @Test func gettingStarted() async throws {

        let sk1 = SecretKey()
        let sk2 = SecretKey()

        let coinbase = BitcoinTransaction(version: .v2, locktime: .disabled, inputs: [
            .init(outpoint: .coinbase, sequence: .final)
        ], outputs: [
            .init(value: 21_000_000, script: .payToPublicKey(sk1.publicKey)),
            .init(value: 21_000_000, script: .payToPublicKeyHash(sk1.publicKey)),
            .init(value: 21_000_000, script: .payToWitnessPublicKeyHash(sk1.publicKey)),
            .init(value: 21_000_000, script: .payToTaproot(sk1.taprootInternalKey))
        ])
        #expect(coinbase.isCoinbase)

        let outpoint0 = try #require(coinbase.outpoint(0))

        let t1 = BitcoinTransaction(version: .v2, locktime: .disabled, inputs: [
            .init(outpoint: outpoint0, sequence: .final),
            // .init(outpoint: coinbase.outpoint(1)!, sequence: .final),
            // .init(outpoint: coinbase.outpoint(2)!, sequence: .final),
            // .init(outpoint: coinbase.outpoint(3)!, sequence: .final)
        ], outputs: [
            .init(value: 21_000_000, script: .empty)
        ])

        let coinbaseOut0 = coinbase.outputs[0]

        let sighash = t1.signatureHash(sighashType: .all, inputIndex: 0, previousOutput: coinbaseOut0, scriptCode: coinbaseOut0.script.data)
        let signature = try #require(sk1.sign(messageHash: sighash, signatureType: .ecdsa))

        let signatureExt = ExtendedSignature(signature, .all)

        let t1_signed = t1.withUnlockScript([.pushBytes(signatureExt.data)], input: 0)
        let result = t1_signed.verifyScript(previousOutputs: [coinbaseOut0], config: .standard)
        #expect(result)
    }
}
