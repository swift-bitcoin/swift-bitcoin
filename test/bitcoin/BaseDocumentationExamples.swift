import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase

struct BaseDocumentationExamples {

    @Test func signSingleKeyIns() async throws {
        let sk = SecretKey()

        // A dummy coinbase transaction (missing some extra information).
        let fund = Transaction(ins: [
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
        var spend = Transaction(ins: [
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

        // For pay-to-public key we just need to sign the hash and add the signature to the input's unlock script.
        let sighash0 = SignatureHash(tx: spend, input: 0, sighashType: .all, scriptCode: prevout0.script.data).data
        let sig0 = sk.sign(hash: sighash0)
        let sigExt0 = ECDSASignature.Extended(sig0, sighashType: .all)
        spend.ins[0].script = [.pushBytes(sigExt0.data)]

        // For pay-to-public-key-hash we need to also add the public key to the unlock script.
        let sighash1 = SignatureHash(tx: spend, input: 1, sighashType: .all, scriptCode: prevout1.script.data).data
        let sig1 = sk.sign(hash: sighash1)
        let sigExt1 = ECDSASignature.Extended(sig1, sighashType: .all)
        spend.ins[1].script = [.pushBytes(sigExt1.data), .pushBytes(sk.pubkey.data)]

        // For pay-to-witness-public-key-hash we sign a different hash and we add the signature and public key to the input's _witness_.
        let sighash2 = SignatureHash.Segwit(tx: spend, input: 2, sighashType: .all, scriptCode: nil, prevout: prevout2).data

        let sig2 = sk.sign(hash: sighash2)
        let sigExt2 = ECDSASignature.Extended(sig2, sighashType: .all)
        spend.ins[2].witness = .init([sigExt2.data, sk.pubkey.data])

        // For pay-to-taproot with key we need a different sighash and a _tweaked_ version of our secret key to sign it. We use the default sighash type which is equal to _all_.
        let sighash3 = SignatureHash.Taproot(tx: spend, input: 3, sighashType: nil, prevouts: [prevout0, prevout1, prevout2, prevout3]).data
        let sig3 = sk.taprootSecretKey().signSchnorr(hash: sighash3)
        let sigExt3 = SchnorrSignature.Extended(sig3, sighashType: nil)
        // The witness only requires the signature
        spend.ins[3].witness = .init([sigExt3.data])

        let result = spend.verifyScript(prevouts: [prevout0, prevout1, prevout2, prevout3])
        #expect(result)
    }

    @Test func signMultisigInput() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            // Multisig 2-out-of-3
            .init(value: 100, script: .payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)),
        ])

        var spend = Transaction(ins: [.init(outpoint: fund.outpoint(0))], outs: [
            .init(value: 100)
        ])

        // These outpoints and previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevout = fund.outs[0]

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let sighash0 = SignatureHash(tx: spend, input: input, sighashType: sighashType, scriptCode: prevout.script.data).data

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ECDSASignature.Extended(sig0, sighashType: sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ECDSASignature.Extended(sig1, sighashType: sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        spend.ins[input].script = [.zero, .pushBytes(sigExt0.data), .pushBytes(sigExt1.data)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashMultisig() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let redeemScript = Script.payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)

        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        var spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [.init(value: 100)])

        let prevout = fund.outs[0]
        let input = 0
        let sighashType = SighashType.all // Same sighash for all signatures
        let sighash0 = SignatureHash(tx: spend, input: input, sighashType: sighashType, scriptCode: redeemScript.data).data

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ECDSASignature.Extended(sig0, sighashType: sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ECDSASignature.Extended(sig1, sighashType: sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        spend.ins[input].script = [.zero, .pushBytes(sigExt0.data), .pushBytes(sigExt1.data), .encodeMinimally(redeemScript.data)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signWitnessScriptHashMultisig() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()
        let redeemScript = Script.payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)

        let fund = Transaction(ins: [
            .init(outpoint: .coinbase)
        ], outs: [
            .init(value: 100, script: .payToWitnessScriptHash(redeemScript)),
        ])

        var spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [
            .init(value: 100)
        ])

        // Same sighash for all signatures
        let prevout = fund.outs[0]
        let input = 0
        let sighashType = SighashType.all
        let sighash0 = SignatureHash.Segwit(tx: spend, input: input, sighashType: sighashType, scriptCode: redeemScript.data, prevout: prevout).data

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ECDSASignature.Extended(sig0, sighashType: sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ECDSASignature.Extended(sig1, sighashType: sighashType)

        // Signatures need to appear in the right order, plus a dummy value
        spend.ins[input].witness = .init([Data(), sigExt0.data, sigExt1.data, redeemScript.data])

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashWitnessKey() async throws {
        let sk = SecretKey()

        let redeemScript = Script.payToWitnessPubkeyHash(sk.pubkey)

        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let prevout = fund.outs[0]

        // Spending transaction.
        var spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [
            .init(value: 100)
        ])

        let pubkey = sk.pubkey
        let pubkeyHash = Data(Hash160.hash(data: pubkey.data))
        let scriptCode = Script.segwitPKHScriptCode(pubkeyHash).data

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let sighash = SignatureHash.Segwit(tx: spend, input: input, sighashType: sighashType, scriptCode: scriptCode, prevout: prevout).data
        let sig = sk.sign(hash: sighash)
        let sigExt = ECDSASignature.Extended(sig, sighashType: sighashType)

        spend.ins[input].witness = .init([sigExt.data, pubkey.data])
        spend.ins[input].script = [.encodeMinimally(redeemScript.data)]

        let result = spend.verifyScript(prevouts: [prevout])
        #expect(result)
    }

    @Test func signScriptHashWitnessScript() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        let witnessScript = Script.payToMultiSignature(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)
        let redeemScript = Script.payToWitnessScriptHash(witnessScript)

        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToScriptHash(redeemScript)),
        ])

        let prevout = fund.outs[0]

        // Spending transaction.
        var spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [
            .init(value: 100)
        ])

        // Same sighash for all signatures
        let input = 0
        let sighashType = SighashType.all
        let sighash0 = SignatureHash.Segwit(tx: spend, input: input, sighashType: sighashType, scriptCode: witnessScript.data, prevout: prevout).data

        let sig0 = sk1.sign(hash: sighash0)
        let sigExt0 = ECDSASignature.Extended(sig0, sighashType: sighashType)

        let sig1 = sk3.sign(hash: sighash0)
        let sigExt1 = ECDSASignature.Extended(sig1, sighashType: sighashType)

        // Signatures need to appear in the right order, plus a dummy value

        spend.ins[input].witness = .init([Data(), sigExt0.data, sigExt1.data, witnessScript.data])
        spend.ins[input].script = [.encodeMinimally(redeemScript.data)]

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

        let tapscript = Script([
            .encodeMinimally(pubkey1.xOnlyData),
            .checkSig,
            .encodeMinimally(pubkey2.xOnlyData),
            .checkSigAdd,
            .encodeMinimally(pubkey3.xOnlyData),
            .checkSigAdd,
            .constant(2),
            .equal
        ]).data
        let scriptTree = TapscriptTree.leaf(0xc0, tapscript)

        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToTaproot(internalKey: internalKey, script: scriptTree)),
        ])

        let prevouts = [fund.outs[0]]
        // Spending transaction.
        var spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
        ], outs: [.init(value: 100)])

        // Same sighash for all signatures
        let input = 0
        let leafIndex = 0 // The leaf index in the script tree.

        let (_, leafHashes, controlBlocks) = internalKey.computeControlBlocks(scriptTree)

        let sighashType = SighashType?.none
        let sighash = SignatureHash.Taproot(tx: spend, input: input, sighashType: sighashType, prevouts: prevouts, tapscriptExtension: .init(tapLeafHash: leafHashes[leafIndex])).data
        let sig1 = sk1.signSchnorr(hash: sighash)
        let sigExt1 = SchnorrSignature.Extended(sig1, sighashType: sighashType)
        let sig3 = sk3.signSchnorr(hash: sighash)
        let sigExt3 = SchnorrSignature.Extended(sig3, sighashType: sighashType)

        spend.ins[input].witness = .init([
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
        let stack = try Script([.constant(1), .constant(1), .add]).run()
        #expect(stack.count == 1)
        let number = try ScriptNumber(stack[0])
        #expect(number.value == 2)
    }
}
