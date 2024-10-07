import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet

struct WalletDocumentationExamples {

    @Test func simpleTransaction() async throws {

        // Bob gets paid.
        let bobsSecretKey = SecretKey()
        let bobsAddress = BitcoinAddress(bobsSecretKey)

        // The funding transaction, sending money to Bob.
        let fundingTransaction = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            bobsAddress.output(100) // 100 satoshis
        ])

        // Alice generates an address to give Bob.

        let alicesSecretKey = SecretKey()
        let alicesAddress = BitcoinAddress(alicesSecretKey)

        // Bob constructs, sings and broadcasts a transaction which pays Alice at her address.

        // The spending transaction by which Bob sends money to Alice
        let spendingTransaction = BitcoinTransaction(inputs: [
            .init(outpoint: fundingTransaction.outpoint(0)),
        ], outputs: [
            alicesAddress.output(50) // 50 satoshis
        ])

        // Sign the spending transaction.
        let prevouts = [fundingTransaction.outputs[0]]
        let signer = TransactionSigner(
            transaction: spendingTransaction, prevouts: prevouts, sighashType: .all
        )
        let signedTransaction = signer.sign(input: 0, with: bobsSecretKey)

        // Verify transaction signatures.
        let result = signedTransaction.verifyScript(prevouts: prevouts)
        #expect(result)
    }

    @Test func signSingleKeyTransactionInputs() async throws {
        let sk = SecretKey()

        let p2pkh = BitcoinAddress(sk)
        let p2sh_p2wpkh = BitcoinAddress(.payToWitnessPublicKeyHash(sk.publicKey))
        let p2wpkh = SegwitAddress(sk)
        let p2tr = TaprootAddress(sk)

        // The funding transaction.
        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 100, script: .payToPublicKey(sk.publicKey)),
            p2pkh.output(200),
            p2sh_p2wpkh.output(300),
            p2wpkh.output(400),
            p2tr.output(500),
        ])

        // A transaction spending all of the outputs from the funding transaction.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
            .init(outpoint: fund.outpoint(1)),
            .init(outpoint: fund.outpoint(2)),
            .init(outpoint: fund.outpoint(3)),
            .init(outpoint: fund.outpoint(4)),
        ], outputs: [
            .init(value: 100)
        ])

        // Do the signing.
        let prevouts = [fund.outputs[0], fund.outputs[1], fund.outputs[2], fund.outputs[3], fund.outputs[4]]
        let signer = TransactionSigner(transaction: spend, prevouts: prevouts, sighashType: .all)
        signer.sign(input: 0, with: sk)
        signer.sign(input: 1, with: sk)
        signer.sign(input: 2, with: sk) // P2SH-P2WPKH
        signer.sign(input: 3, with: sk)
        signer.sighashType = Optional.none
        let signed = signer.sign(input: 4, with: sk)

        // Verify transaction signatures.
        let result = signed.verifyScript(prevouts: prevouts)
        #expect(result)
    }

    @Test func signMultisigTransactionInputs() async throws {
        let sk1 = SecretKey(); let sk2 = SecretKey(); let sk3 = SecretKey()

        // Multisig 2-out-of-3
        let multisigScript = BitcoinScript.payToMultiSignature(2, of: sk1.publicKey, sk2.publicKey, sk3.publicKey)

        // Some different types of addresses
        let p2sh = BitcoinAddress(multisigScript)
        let p2sh_p2wsh = BitcoinAddress(.payToWitnessScriptHash(multisigScript))
        let p2wsh = SegwitAddress(multisigScript)

        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 100, script: multisigScript),
            p2sh.output(200),
            p2sh_p2wsh.output(300),
            p2wsh.output(400)
        ])

        // A transaction spending all of the outputs from our coinbase transaction.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: fund.outpoint(0)),
            .init(outpoint: fund.outpoint(1)),
            .init(outpoint: fund.outpoint(2)),
            .init(outpoint: fund.outpoint(3)),
        ], outputs: [.init(value: 21_000_000)])

        // These outpoints and previous outputs all happen to come from the same transaction but they don't necessarilly have to.
        let prevouts = [fund.outputs[0], fund.outputs[1], fund.outputs[2], fund.outputs[3]]
        let signer = TransactionSigner(transaction: spend, prevouts: prevouts, sighashType: .all)
        signer.sign(input: 0, with: [sk1, sk2])
        signer.sign(input: 1, redeemScript: multisigScript, with: [sk2, sk3])
        signer.sign(input: 2, witnessScript: multisigScript, with: [sk1, sk3]) // p2sh-p2wsh
        let signed = signer.sign(input: 3, witnessScript: multisigScript, with: [sk1, sk2])

        // Verify transaction signatures.
        let result = signed.verifyScript(prevouts: prevouts)
        #expect(result)
    }
}
