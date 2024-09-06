import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase

struct BaseDocumentationExamples {

    @Test func signingTransactions() async throws {
        let sk = SecretKey()

        // A dummy coinbase transaction (missing some extra information).
        let coinbase = BitcoinTransaction(version: .v2, locktime: .disabled, inputs: [
            .init(outpoint: .coinbase, sequence: .final)
        ], outputs: [
            .init(value: 21_000_000, script: .payToPublicKey(sk.publicKey)),
            .init(value: 21_000_000, script: .payToPublicKeyHash(sk.publicKey)),
            .init(value: 21_000_000, script: .payToWitnessPublicKeyHash(sk.publicKey)),
            // Pay-to-taproot requires an internal key instead of the regular public key.
            .init(value: 21_000_000, script: .payToTaproot(sk.taprootInternalKey)),
            .init(value: 0, script: .dataCarrier("Hello, Bitcoin!"))
        ])
        #expect(coinbase.isCoinbase)

        // These outpoints all happen to come from the same transaction but they don't necessarilly have to.
        let outpoint0 = try #require(coinbase.outpoint(0))
        let outpoint1 = try #require(coinbase.outpoint(1))
        let outpoint2 = try #require(coinbase.outpoint(2))
        let outpoint3 = try #require(coinbase.outpoint(3))
        // A transaction spending all of the outputs from our coinbase transaction.
        let tx = BitcoinTransaction(version: .v2, locktime: .disabled, inputs: [
            .init(outpoint: outpoint0, sequence: .final),
            .init(outpoint: outpoint1, sequence: .final),
            .init(outpoint: outpoint2, sequence: .final),
            .init(outpoint: outpoint3, sequence: .final),
        ], outputs: [
            .init(value: 21_000_000, script: .empty)
        ])

        // These previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevout0 = coinbase.outputs[0]
        let prevout1 = coinbase.outputs[1]
        let prevout2 = coinbase.outputs[2]
        let prevout3 = coinbase.outputs[3]


        var sighash = SignatureHash(transaction: tx, input: 0, prevout: prevout0, sigVersion: .base, sighashType: .all)

        // For pay-to-public key we just need to sign the hash and add the signature to the input's unlock script.
        let sighash0 = try sighash.value
        let signature0 = try #require(sk.sign(messageHash: sighash0, signatureType: .ecdsa))
        let signatureExt0 = ExtendedSignature(signature0, .all)
        var tx_signed = tx.withUnlockScript([.pushBytes(signatureExt0.data)], input: 0)

        // For pay-to-public-key-hash we need to also add the public key to the unlock script.
        sighash.set(input: 1, prevout: prevout1)
        let sighash1 = try sighash.value
        let signature1 = try #require(sk.sign(messageHash: sighash1, signatureType: .ecdsa))
        let signatureExt1 = ExtendedSignature(signature1, .all)
        tx_signed = tx_signed.withUnlockScript([.pushBytes(signatureExt1.data), .pushBytes(sk.publicKey.data)], input: 1)

        // For pay-to-witness-public-key-hash we sign a different hash and we add the signature and public key to the input's _witness_.
        sighash.set(input: 2, prevout: prevout2)
        let sighash2 = try sighash.value
        let signature2 = try #require(sk.sign(messageHash: sighash2, signatureType: .ecdsa))
        let signatureExt2 = ExtendedSignature(signature2, .all)
        tx_signed = tx_signed.withWitness([signatureExt2.data, sk.publicKey.data], input: 2)

        // For pay-to-taproot with key we need a different sighash and a _tweaked_ version of our secret key to sign it. We use the default sighash type which is equal to _all_.
        sighash.set(input: 3, prevouts: [prevout0, prevout1, prevout2, prevout3])
        sighash.sighashType = Optional.none
        let sighash3 = try sighash.value
        let signature3 = try #require(sk.taprootSecretKey().sign(messageHash: sighash3, signatureType: .schnorr))
        let signatureExt3 = ExtendedSignature(signature3, Optional.none)
        // The witness only requires the signature
        tx_signed = tx_signed.withWitness([signatureExt3.data], input: 3)

        let result = tx_signed.verifyScript(prevouts: [prevout0, prevout1, prevout2, prevout3], config: .standard)
        #expect(result)
    }

    @Test func signingMultisig() async throws {
        let sk1 = SecretKey()
        let sk2 = SecretKey()
        let sk3 = SecretKey()

        // A dummy coinbase transaction (missing some extra information).
        let coinbase = BitcoinTransaction(version: .v2, locktime: .disabled, inputs: [
            .init(outpoint: .coinbase, sequence: .final)
        ], outputs: [
            // Multisig 2-out-of-3
            .init(value: 21_000_000, script: .payToMultiSignature(2, of: sk1.publicKey, sk2.publicKey, sk3.publicKey)),
        ])
        #expect(coinbase.isCoinbase)

        // These outpoints and previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let outpoint0 = try #require(coinbase.outpoint(0))
        let prevout0 = coinbase.outputs[0]

        // A transaction spending all of the outputs from our coinbase transaction.
        let tx = BitcoinTransaction(version: .v2, locktime: .disabled, inputs: [
            .init(outpoint: outpoint0, sequence: .final),
        ], outputs: [
            .init(value: 21_000_000, script: .empty)
        ])

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let sighash = SignatureHash(transaction: tx, input: input, prevout: prevout0, sigVersion: .base, sighashType: sighashType)
        let sighash0 = try sighash.value

        let signature0 = try #require(sk1.sign(messageHash: sighash0, signatureType: .ecdsa))
        let signatureExt0 = ExtendedSignature(signature0, sighashType)

        let signature1 = try #require(sk3.sign(messageHash: sighash0, signatureType: .ecdsa))
        let signatureExt1 = ExtendedSignature(signature1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        let tx_signed = tx.withUnlockScript([.zero, .pushBytes(signatureExt0.data), .pushBytes(signatureExt1.data)], input: input)

        let result = tx_signed.verifyScript(prevouts: [prevout0], config: .standard)
        #expect(result)
    }

    // TODO: `@Test func signingMultisig() async throws { }`
    // TODO: `@Test func signingScriptHash() async throws { }`
    // TODO: `@Test func signingWitnessScriptHash() async throws { }`
    // TODO: `@Test func signingTapscript() async throws { }`

    @Test func standaloneScript() async throws {
        let stack = try BitcoinScript([.constant(1), .constant(1), .add]).run()
        #expect(stack.count == 1)
        let number = try ScriptNumber(stack[0])
        #expect(number.value == 2)
    }
}
