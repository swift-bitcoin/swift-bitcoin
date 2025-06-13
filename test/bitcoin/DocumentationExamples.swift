import Foundation
import Testing
import Bitcoin

struct DocumentationExamples {

    @Test func gettingStarted() async throws {
        // Generate a secret key, corresponding public key, hash and address.
        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey
        let address = LegacyAddress(pubkey)

        // # Prepare the Blockchain service.

        // Create a fresh blockchain service instance (on regtest).
        let blockchain = BlockchainService()
        await blockchain.start()

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        var blocks = [Block]()
        for _ in 1 ... 100 {
            blocks.append(await blockchain.generateTo(address.script)!)
        }

        // # Prepare our transaction.

        // Grab block 1's coinbase transaction and output.
        let fundingTx = blocks[0].txs[0]
        let prevout = fundingTx.outs[0]

        // Create a new transaction spending from the previous transaction's outpoint.
        let unsignedInput = Transaction.Input(outpoint: fundingTx.outpoint(0))

        // Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
        let spendingTx = Transaction(ins: [unsignedInput], outs: [address.out(100)])

        // # We now need to sign the transaction using our secret key.

        var signer = TransactionSigner(tx: spendingTx, prevouts: [prevout])
        let signedTx = signer.sign(input: 0, with: secretKey)

        // # We can verify that the transaction was signed correctly.

        // Make sure the transaction was signed correctly by verifying the scripts.
        let isVerified = signedTx.verifyScript(prevouts: [prevout])

        #expect(isVerified)
        // Yay! Our transaction is valid.

        // # Now we're ready to submit our signed transaction to the mempool.

        // Submit the signed transaction to the mempool.
        try await blockchain.addTransaction(signedTx)

        // The mempool should now contain our transaction.
        #expect(await blockchain.mempool.count == 1)

        // # After confirming the transaction was accepted we can mine a block and get it confirmed.

        // Let's mine another block to confirm our transaction.

        // Mine one block to our address.
        let lastBlock = await blockchain.generateTo(address.script)!

        // The mempool should now be empty.
        #expect(await blockchain.mempool.count == 0)

        // # Finally let's make sure the transaction was confirmed in a block.

        #expect(await blockchain.height == 101)

        // Verify our transaction was confirmed in a block.
        #expect(lastBlock.txs[1] == signedTx)

        // Our transaction is now confirmed in the blockchain!
        await blockchain.stop()
    }
}
