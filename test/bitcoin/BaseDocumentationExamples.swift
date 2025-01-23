import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase

struct BaseDocumentationExamples {

    @Test func signSingleKeyIns() async throws {
        let sk = SecretKey()

        // A dummy coinbase transaction (missing some extra information).
        let fund = BitcoinTx(ins: [
            .init(outpoint: .coinbase)
        ], outs: [
            .init(value: 100, script: .payToPubkey(sk.pubkey)),
            .init(value: 100, script: .payToPubkeyHash(sk.pubkey)),
            .init(value: 100, script: .payToWitnessPubkeyHash(sk.pubkey)),
            // Pay-to-taproot requires an internal key instead of the regular public key.
            .init(value: 100, script: .payToTaproot(internalKey: sk.taprootInternalKey)),
            .init(value: 0, script: .dataCarrier("Hello, Bitcoin!"))
        ])
        #expect(fund.isCoinbase)

        // A transaction spending all of the outputs from our coinbase transaction.
        // These outpoints all happen to come from the same transaction but they don't necessarilly have to.
        var spend = BitcoinTx(ins: [
            .init(outpoint: fund.outpoint(0)),
            .init(outpoint: fund.outpoint(1)),
            .init(outpoint: fund.outpoint(2)),
            .init(outpoint: fund.outpoint(3)),
        ], outs: [
            .init(value: 100)
        ])

        // These previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevout0 = fund.outs[0]
        let prevout1 = fund.outs[1]
        let prevout2 = fund.outs[2]
        let prevout3 = fund.outs[3]

        let hasher = SigHash(tx: spend, txIn: 0, prevout: prevout0, sighashType: .all)

        // For pay-to-public key we just need to sign the hash and add the signature to the input's unlock script.
        let sighash0 = hasher.value
        let sig0 = sk.sign(hash: sighash0)
        let sigExt0 = ExtendedSig(sig0, .all)
        spend.ins[0].script = [.pushBytes(sigExt0.data)]

        // For pay-to-public-key-hash we need to also add the public key to the unlock script.
        hasher.set(txIn: 1, prevout: prevout1)
        let sighash1 = hasher.value
        let sig1 = sk.sign(hash: sighash1)
        let sigExt1 = ExtendedSig(sig1, .all)
        spend.ins[1].script = [.pushBytes(sigExt1.data), .pushBytes(sk.pubkey.data)]

        // For pay-to-witness-public-key-hash we sign a different hash and we add the signature and public key to the input's _witness_.
        hasher.set(txIn: 2, sigVersion: .witnessV0, prevout: prevout2)
        let sighash2 = hasher.value
        let sig2 = sk.sign(hash: sighash2)
        let sigExt2 = ExtendedSig(sig2, .all)
        spend.ins[2].witness = .init([sigExt2.data, sk.pubkey.data])

        // For pay-to-taproot with key we need a different sighash and a _tweaked_ version of our secret key to sign it. We use the default sighash type which is equal to _all_.
        hasher.set(txIn: 3, sigVersion: .witnessV1, prevouts: [prevout0, prevout1, prevout2, prevout3], sighashType: Optional.none)
        let sighash3 = hasher.value
        let sig3 = sk.taprootSecretKey().sign(hash: sighash3, sigType: .schnorr)
        let sigExt3 = ExtendedSig(sig3, Optional.none)
        // The witness only requires the signature
        spend.ins[3].witness = .init([sigExt3.data])

        let result = spend.verifyScript(prevouts: [prevout0, prevout1, prevout2, prevout3])
        #expect(result)
    }

    @Test func signMultisigInput() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let fund = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [
            // Multisig 2-out-of-3
            .init(value: 100, script: .payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)),
        ])

        var spend = BitcoinTx(ins: [.init(outpoint: fund.outpoint(0))], outs: [
            .init(value: 100)
        ])

        // These outpoints and previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevout = fund.outs[0]

        // Same sighash for all signatures
        let txIn = 0
        let sighashType = SighashType.all
        let hasher = SigHash(tx: spend, txIn: txIn, prevout: prevout, sighashType: sighashType)
        let sighash0 = hasher.value

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ExtendedSig(sig0, sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ExtendedSig(sig1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        spend.ins[txIn].script = [.zero, .pushBytes(sigExt0.data), .pushBytes(sigExt1.data)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashMultisig() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let redeemScript = BitcoinScript.payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)

        let fund = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        var spend = BitcoinTx(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [.init(value: 100)])

        let prevout = fund.outs[0]
        let txIn = 0
        let sighashType = SighashType.all // Same sighash for all signatures
        let hasher = SigHash(tx: spend, txIn: txIn, prevout: prevout, scriptCode: redeemScript.binaryData, sighashType: sighashType)
        let sighash0 = hasher.value

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ExtendedSig(sig0, sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ExtendedSig(sig1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        spend.ins[txIn].script = [.zero, .pushBytes(sigExt0.data), .pushBytes(sigExt1.data), .encodeMinimally(redeemScript.binaryData)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signWitnessScriptHashMultisig() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()
        let redeemScript = BitcoinScript.payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)

        let fund = BitcoinTx(ins: [
            .init(outpoint: .coinbase)
        ], outs: [
            .init(value: 100, script: .payToWitnessScriptHash(redeemScript)),
        ])

        var spend = BitcoinTx(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [
            .init(value: 100)
        ])

        // Same sighash for all signatures
        let prevout = fund.outs[0]
        let txIn = 0
        let sighashType = SighashType.all
        let hasher = SigHash(tx: spend, txIn: txIn, sigVersion: .witnessV0, prevout: prevout, scriptCode: redeemScript.binaryData, sighashType: sighashType)
        let sighash0 = hasher.value

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ExtendedSig(sig0, sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ExtendedSig(sig1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        spend.ins[txIn].witness = .init([Data(), sigExt0.data, sigExt1.data, redeemScript.binaryData])

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashWitnessKey() async throws {
        let sk = SecretKey()

        let redeemScript = BitcoinScript.payToWitnessPubkeyHash(sk.pubkey)

        let fund = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let prevout = fund.outs[0]

        // Spending transaction.
        var spend = BitcoinTx(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [
            .init(value: 100)
        ])

        let pubkey = sk.pubkey
        let pubkeyHash = Data(Hash160.hash(data: pubkey.data))
        let scriptCode = BitcoinScript.segwitPKHScriptCode(pubkeyHash).binaryData

        // Same sighash for all signatures
        let txIn = 0
        let sighashType = SighashType.all
        let hasher = SigHash(tx: spend, txIn: txIn, sigVersion: .witnessV0, prevout: prevout, scriptCode: scriptCode, sighashType: sighashType)
        let sighash = hasher.value
        let sig = sk.sign(hash: sighash)
        let sigExt = ExtendedSig(sig, sighashType)

        spend.ins[txIn].witness = .init([sigExt.data, pubkey.data])
        spend.ins[txIn].script = [.encodeMinimally(redeemScript.binaryData)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashWitnessScript() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let witnessScript = BitcoinScript.payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)
        let redeemScript = BitcoinScript.payToWitnessScriptHash(witnessScript)

        let fund = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let prevout = fund.outs[0]

        // Spending transaction.
        var spend = BitcoinTx(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [
            .init(value: 100)
        ])

        // Same sighash for all signatures
        let txIn = 0
        let sighashType = SighashType.all
        let hasher = SigHash(tx: spend, txIn: txIn, sigVersion: .witnessV0, prevout: prevout, scriptCode: witnessScript.binaryData, sighashType: sighashType)
        let sighash0 = hasher.value

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ExtendedSig(sig0, sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ExtendedSig(sig1, sighashType)

        // Signatures need to appear in the right order, plus a dummy value

        spend.ins[txIn].witness = .init([Data(), sigExt0.data, sigExt1.data, witnessScript.binaryData])
        spend.ins[txIn].script = [.encodeMinimally(redeemScript.binaryData)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signTapscript() async throws {
        let sk = SecretKey()
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()
        let internalKey = sk.taprootInternalKey
        let pubkey1 = sk1.xOnlyPubkey
        let pubkey2 = sk2.xOnlyPubkey
        let pubkey3 = sk3.xOnlyPubkey

        let tapscript = BitcoinScript([
            .encodeMinimally(pubkey1.xOnlyData),
            .checkSig,
            .encodeMinimally(pubkey2.xOnlyData),
            .checkSigAdd,
            .encodeMinimally(pubkey3.xOnlyData),
            .checkSigAdd,
            .constant(2),
            .equal
        ]).binaryData
        let scriptTree = ScriptTree.leaf(0xc0, tapscript)

        let fund = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToTaproot(internalKey: internalKey, script: scriptTree)),
        ])

        let prevouts = [fund.outs[0]]
        // Spending transaction.
        var spend = BitcoinTx(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [.init(value: 100)])

        // Same sighash for all signatures
        let txIn = 0
        let leafIndex = 0 // The leaf index in the script tree.

        let (_, leafHashes, controlBlocks) = internalKey.computeControlBlocks(scriptTree)

        let sighashType = SighashType?.none
        let hasher = SigHash(tx: spend, txIn: txIn, sigVersion: .witnessV1, prevouts: prevouts, tapscriptExtension: .init(tapLeafHash: leafHashes[leafIndex]), sighashType: sighashType)

        let sighash = hasher.value
        let sig1 = sk1.sign(hash: sighash, sigType: .schnorr)
        let sigExt1 = ExtendedSig(sig1, sighashType)
        let sig3 = sk3.sign(hash: sighash, sigType: .schnorr)
        let sigExt3 = ExtendedSig(sig3, sighashType)

        spend.ins[txIn].witness = .init([
            sigExt3.data,
            Data(),
            sigExt1.data,
            tapscript,
            controlBlocks[0]
        ])

        let result = spend.verifyScript(prevouts: prevouts)
        #expect(result)
    }

    @Test func standaloneScript() async throws {
        let stack = try BitcoinScript([.constant(1), .constant(1), .add]).run()
        #expect(stack.count == 1)
        let number = try ScriptNum(stack[0])
        #expect(number.value == 2)
    }
}
