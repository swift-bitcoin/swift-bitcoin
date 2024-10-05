import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase

struct BaseDocumentationExamples {

    @Test func signSingleKeyInputs() async throws {
        let sk = SecretKey()

        // A dummy coinbase transaction (missing some extra information).
        let fund = BitcoinTransaction(inputs: [
            .init(outpoint: .coinbase)
        ], outputs: [
            .init(value: 100, script: .payToPublicKey(sk.publicKey)),
            .init(value: 100, script: .payToPublicKeyHash(sk.publicKey)),
            .init(value: 100, script: .payToWitnessPublicKeyHash(sk.publicKey)),
            // Pay-to-taproot requires an internal key instead of the regular public key.
            .init(value: 100, script: .payToTaproot(internalKey: sk.taprootInternalKey)),
            .init(value: 0, script: .dataCarrier("Hello, Bitcoin!"))
        ])
        #expect(fund.isCoinbase)

        // A transaction spending all of the outputs from our coinbase transaction.
        // These outpoints all happen to come from the same transaction but they don't necessarilly have to.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
            .init(outpoint: fund.outpoint(1)),
            .init(outpoint: fund.outpoint(2)),
            .init(outpoint: fund.outpoint(3)),
        ], outputs: [
            .init(value: 100)
        ])

        // These previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevout0 = fund.outputs[0]
        let prevout1 = fund.outputs[1]
        let prevout2 = fund.outputs[2]
        let prevout3 = fund.outputs[3]

        let hasher = SignatureHash(transaction: spend, input: 0, prevout: prevout0, sighashType: .all)

        // For pay-to-public key we just need to sign the hash and add the signature to the input's unlock script.
        let sighash0 = hasher.value
        let signature0 = sk.sign(hash: sighash0)
        let signatureExt0 = ExtendedSignature(signature0, .all)
        var tx_signed = spend.withUnlockScript([.pushBytes(signatureExt0.data)], input: 0)

        // For pay-to-public-key-hash we need to also add the public key to the unlock script.
        hasher.set(input: 1, prevout: prevout1)
        let sighash1 = hasher.value
        let signature1 = sk.sign(hash: sighash1)
        let signatureExt1 = ExtendedSignature(signature1, .all)
        tx_signed = tx_signed.withUnlockScript([.pushBytes(signatureExt1.data), .pushBytes(sk.publicKey.data)], input: 1)

        // For pay-to-witness-public-key-hash we sign a different hash and we add the signature and public key to the input's _witness_.
        hasher.set(input: 2, sigVersion: .witnessV0, prevout: prevout2)
        let sighash2 = hasher.value
        let signature2 = sk.sign(hash: sighash2)
        let signatureExt2 = ExtendedSignature(signature2, .all)
        tx_signed = tx_signed.withWitness([signatureExt2.data, sk.publicKey.data], input: 2)

        // For pay-to-taproot with key we need a different sighash and a _tweaked_ version of our secret key to sign it. We use the default sighash type which is equal to _all_.
        hasher.set(input: 3, sigVersion: .witnessV1, prevouts: [prevout0, prevout1, prevout2, prevout3], sighashType: Optional.none)
        let sighash3 = hasher.value
        let signature3 = sk.taprootSecretKey().sign(hash: sighash3, signatureType: .schnorr)
        let signatureExt3 = ExtendedSignature(signature3, Optional.none)
        // The witness only requires the signature
        tx_signed = tx_signed.withWitness([signatureExt3.data], input: 3)

        let result = tx_signed.verifyScript(prevouts: [prevout0, prevout1, prevout2, prevout3])
        #expect(result)
    }

    @Test func signMultisigInput() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            // Multisig 2-out-of-3
            .init(value: 100, script: .payToMultiSignature(2, of: sk1.publicKey, sk2.publicKey, sk3.publicKey)),
        ])

        let spend = BitcoinTransaction(inputs: [.init(outpoint: fund.outpoint(0))], outputs: [
            .init(value: 100)
        ])

        // These outpoints and previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevout = fund.outputs[0]

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let hasher = SignatureHash(transaction: spend, input: input, prevout: prevout, sighashType: sighashType)
        let sighash0 = hasher.value

        let signature0 = sk1.sign(hash: sighash0)
        let signatureExt0 = ExtendedSignature(signature0, sighashType)

        let signature1 = sk3.sign(hash: sighash0)
        let signatureExt1 = ExtendedSignature(signature1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        let tx_signed = spend.withUnlockScript([.zero, .pushBytes(signatureExt0.data), .pushBytes(signatureExt1.data)], input: input)

        let result = tx_signed.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashMultisig() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let redeemScript = BitcoinScript.payToMultiSignature(2, of: sk1.publicKey, sk2.publicKey, sk3.publicKey)

        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
        ], outputs: [.init(value: 100)])

        let prevout = fund.outputs[0]
        let input = 0
        let sighashType = SighashType.all // Same sighash for all signatures
        let hasher = SignatureHash(transaction: spend, input: input, prevout: prevout, scriptCode: redeemScript.data, sighashType: sighashType)
        let sighash0 = hasher.value

        let signature0 = sk1.sign(hash: sighash0)
        let signatureExt0 = ExtendedSignature(signature0, sighashType)

        let signature1 = sk3.sign(hash: sighash0)
        let signatureExt1 = ExtendedSignature(signature1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        let tx_signed = spend.withUnlockScript([.zero, .pushBytes(signatureExt0.data), .pushBytes(signatureExt1.data), .encodeMinimally(redeemScript.data)], input: input)

        let result = tx_signed.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signWitnessScriptHashMultisig() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()
        let redeemScript = BitcoinScript.payToMultiSignature(2, of: sk1.publicKey, sk2.publicKey, sk3.publicKey, sigVersion: .witnessV0)

        let fund = BitcoinTransaction(inputs: [
            .init(outpoint: .coinbase)
        ], outputs: [
            .init(value: 100, script: .payToWitnessScriptHash(redeemScript)),
        ])

        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
        ], outputs: [
            .init(value: 100)
        ])

        // Same sighash for all signatures
        let prevout = fund.outputs[0]
        let input = 0
        let sighashType = SighashType.all
        let hasher = SignatureHash(transaction: spend, input: input, sigVersion: .witnessV0, prevout: prevout, scriptCode: redeemScript.data, sighashType: sighashType)
        let sighash0 = hasher.value

        let signature0 = sk1.sign(hash: sighash0)
        let signatureExt0 = ExtendedSignature(signature0, sighashType)

        let signature1 = sk3.sign(hash: sighash0)
        let signatureExt1 = ExtendedSignature(signature1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        let tx_signed = spend.withWitness([Data(), signatureExt0.data, signatureExt1.data, redeemScript.data], input: input)

        let result = tx_signed.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashWitnessKey() async throws {
        let sk = SecretKey()

        let redeemScript = BitcoinScript.payToWitnessPublicKeyHash(sk.publicKey)

        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let prevout = fund.outputs[0]

        // Spending transaction.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
        ], outputs: [
            .init(value: 100)
        ])

        let publicKey = sk.publicKey
        let publicKeyHash = Data(Hash160.hash(data: publicKey.data))
        let scriptCode = BitcoinScript.segwitPKHScriptCode(publicKeyHash).data

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let hasher = SignatureHash(transaction: spend, input: input, sigVersion: .witnessV0, prevout: prevout, scriptCode: scriptCode, sighashType: sighashType)
        let sighash = hasher.value
        let signature = sk.sign(hash: sighash)
        let signatureExt = ExtendedSignature(signature, sighashType)
        let tx_signed = spend.withWitness([signatureExt.data, publicKey.data], input: input).withUnlockScript([.encodeMinimally(redeemScript.data)], input: input)

        let result = tx_signed.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashWitnessScript() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let witnessScript = BitcoinScript.payToMultiSignature(2, of: sk1.publicKey, sk2.publicKey, sk3.publicKey, sigVersion: .witnessV0)
        let redeemScript = BitcoinScript.payToWitnessScriptHash(witnessScript)

        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let prevout = fund.outputs[0]

        // Spending transaction.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
        ], outputs: [
            .init(value: 100)
        ])

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let hasher = SignatureHash(transaction: spend, input: input, sigVersion: .witnessV0, prevout: prevout, scriptCode: witnessScript.data, sighashType: sighashType)
        let sighash0 = hasher.value

        let signature0 = sk1.sign(hash: sighash0)
        let signatureExt0 = ExtendedSignature(signature0, sighashType)

        let signature1 = sk3.sign(hash: sighash0)
        let signatureExt1 = ExtendedSignature(signature1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        let tx_signed = spend.withWitness([Data(), signatureExt0.data, signatureExt1.data, witnessScript.data], input: input).withUnlockScript([.encodeMinimally(redeemScript.data)], input: input)

        let result = tx_signed.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signTapscript() async throws {
        let sk = SecretKey()
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()
        let internalKey = sk.taprootInternalKey
        let publicKey1 = sk1.xOnlyPublicKey
        let publicKey2 = sk2.xOnlyPublicKey
        let publicKey3 = sk3.xOnlyPublicKey

        let tapscript = BitcoinScript([
            .encodeMinimally(publicKey1.xOnlyData),
            .checkSig,
            .encodeMinimally(publicKey2.xOnlyData),
            .checkSigAdd,
            .encodeMinimally(publicKey3.xOnlyData),
            .checkSigAdd,
            .constant(2),
            .equal
        ], sigVersion: .witnessV1).data
        let scriptTree = ScriptTree.leaf(0xc0, tapscript)

        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 100, script: .payToTaproot(internalKey: internalKey, script: scriptTree)),
        ])

        let prevouts = [fund.outputs[0]]
        // Spending transaction.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
        ], outputs: [.init(value: 100)])

        // Same sighash for all signatures
        let input = 0
        let leafIndex = 0 // The leaf index in the script tree.

        let (_, leafHashes, controlBlocks) = internalKey.computeControlBlocks(scriptTree)

        let sighashType = SighashType?.none
        let hasher = SignatureHash(transaction: spend, input: input, sigVersion: .witnessV1, prevouts: prevouts, tapscriptExtension: .init(tapLeafHash: leafHashes[leafIndex]), sighashType: sighashType)

        let sighash = hasher.value
        let signature1 = sk1.sign(hash: sighash, signatureType: .schnorr)
        let signatureExt1 = ExtendedSignature(signature1, sighashType)
        let signature3 = sk3.sign(hash: sighash, signatureType: .schnorr)
        let signatureExt3 = ExtendedSignature(signature3, sighashType)

        let tx_signed = spend.withWitness([
            signatureExt3.data,
            Data(),
            signatureExt1.data,
            tapscript,
            controlBlocks[0]
        ], input: input)

        let result = tx_signed.verifyScript(prevouts: prevouts)
        #expect(result)
    }

    @Test func standaloneScript() async throws {
        let stack = try BitcoinScript([.constant(1), .constant(1), .add]).run()
        #expect(stack.count == 1)
        let number = try ScriptNumber(stack[0])
        #expect(number.value == 2)
    }
}
