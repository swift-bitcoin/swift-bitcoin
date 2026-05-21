import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet

struct WalletDocumentationExamples {

    @Test func simpleTx() async throws {

        // Bob gets paid.
        let bobsSecretKey = SecretKey()
        let bobsAddress = LegacyAddress(bobsSecretKey)

        // The funding transaction, sending money to Bob.
        let fundingTx = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            bobsAddress.out(100) // 100 satoshis
        ])

        // Alice generates an address to give Bob.

        let alicesSecretKey = SecretKey()
        let alicesAddress = LegacyAddress(alicesSecretKey)

        // Bob constructs, sings and broadcasts a transaction which pays Alice at her address.

        // The spending transaction by which Bob sends money to Alice
        let spendingTx = Transaction(ins: [
            .init(outpoint: fundingTx.outpoint(0)),
        ], outs: [
            alicesAddress.out(50) // 50 satoshis
        ])

        // Sign the spending transaction.
        let prevouts = [fundingTx.outs[0]]
        var signer = TransactionSigner(
            tx: spendingTx, prevouts: prevouts, sighashType: .all
        )
        let signedTx = signer.sign(input: 0, with: bobsSecretKey)

        // Verify transaction signatures.
        let result = signedTx.verifyScripts(prevouts: prevouts)
        #expect(result)
    }

    @Test func signSingleKeyTransactionIns() async throws {
        let sk = SecretKey()

        let p2pkh = LegacyAddress(sk)
        let p2sh_p2wpkh = LegacyAddress(.payToWitnessPubkeyHash(sk.pubkey))
        let p2wpkh = SegwitAddress(sk)
        let p2tr = TaprootAddress(sk)

        // The funding transaction.
        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: .payToPubkey(sk.pubkey)),
            p2pkh.out(200),
            p2sh_p2wpkh.out(300),
            p2wpkh.out(400),
            p2tr.out(500),
        ])

        // A transaction spending all of the outs from the funding transaction.
        let spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
            .init(outpoint: fund.outpoint(1)),
            .init(outpoint: fund.outpoint(2)),
            .init(outpoint: fund.outpoint(3)),
            .init(outpoint: fund.outpoint(4)),
        ], outs: [
            .init(value: 100)
        ])

        // Do the signing.
        let prevouts = [fund.outs[0], fund.outs[1], fund.outs[2], fund.outs[3], fund.outs[4]]
        var signer = TransactionSigner(tx: spend, prevouts: prevouts, sighashType: .all)
        signer.sign(input: 0, with: sk)
        signer.sign(input: 1, with: sk)
        signer.sign(input: 2, with: sk) // P2SH-P2WPKH
        signer.sign(input: 3, with: sk)
        signer.sighashType = nil
        let signed = signer.sign(input: 4, with: sk)

        // Verify transaction signatures.
        let result = signed.verifyScripts(prevouts: prevouts)
        #expect(result)
    }

    @Test func signMultisigTransactionIns() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        // Multisig 2-out-of-3
        let multisigScript = Script.payToMultisig(2, of: sk1.pubkey, sk2.pubkey, sk3.pubkey)

        // Some different types of addresses
        let p2sh = LegacyAddress(multisigScript)
        let p2sh_p2wsh = LegacyAddress(.payToWitnessScriptHash(multisigScript))
        let p2wsh = SegwitAddress(multisigScript)

        let fund = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
            .init(value: 100, script: multisigScript),
            p2sh.out(200),
            p2sh_p2wsh.out(300),
            p2wsh.out(400)
        ])

        // A transaction spending all of the outputs from our coinbase transaction.
        let spend = Transaction(ins: [
            .init(outpoint: fund.outpoint(0)),
            .init(outpoint: fund.outpoint(1)),
            .init(outpoint: fund.outpoint(2)),
            .init(outpoint: fund.outpoint(3)),
        ], outs: [.init(value: 21_000_000)])

        // These outpoints and previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevouts = [fund.outs[0], fund.outs[1], fund.outs[2], fund.outs[3]]
        var signer = TransactionSigner(tx: spend, prevouts: prevouts, sighashType: .all)
        signer.sign(input: 0, with: [sk1, sk2])
        signer.sign(input: 1, redeemScript: multisigScript, with: [sk2, sk3])
        signer.sign(input: 2, witnessScript: multisigScript, with: [sk1, sk3]) // p2sh-p2wsh
        let signed = signer.sign(input: 3, witnessScript: multisigScript, with: [sk1, sk2])

        // Verify transaction signatures.
        let result = signed.verifyScripts(prevouts: prevouts)
        #expect(result)
    }
}
