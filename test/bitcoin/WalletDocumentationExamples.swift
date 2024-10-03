import Foundation
import Testing
import BitcoinCrypto
import BitcoinBase
import BitcoinWallet

struct WalletDocumentationExamples {

    @Test func signingTransactions() async throws {
        let sk = SecretKey()

        let addressA = BitcoinAddress(sk)
        let addressB = SegwitAddress(sk)
        let addressC = TaprootAddress(sk)

        // The funding transaction.
        let fund = BitcoinTransaction(inputs: [.init(outpoint: .coinbase)], outputs: [
            .init(value: 21_000_000, script: .payToPublicKey(sk.publicKey)),
            addressA.output(21_000_000),
            addressB.output(21_000_000),
            addressC.output(21_000_000),
        ])

        // A transaction spending all of the outputs from the funding transaction.
        let spend = BitcoinTransaction(inputs: [
            .init(outpoint: try #require(fund.outpoint(0))),
            .init(outpoint: try #require(fund.outpoint(1))),
            .init(outpoint: try #require(fund.outpoint(2))),
            .init(outpoint: try #require(fund.outpoint(3))),
        ], outputs: [
            .init(value: 21_000_000)
        ])

        // Do the signing.
        let prevouts = [fund.outputs[0], fund.outputs[1], fund.outputs[2], fund.outputs[3] ]
        let signer = TransactionSigner(transaction: spend, prevouts: prevouts, sighashType: .all)
        signer.sign(input: 0, with: sk)
        signer.sign(input: 1, with: sk)
        signer.sign(input: 2, with: sk)
        signer.sighashType = Optional.none
        let signed = signer.sign(input: 3, with: sk)

        // Verify transaction signatures.
        let result = signed.verifyScript(prevouts: prevouts)
        #expect(result)
    }
}
