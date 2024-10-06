import Foundation
import Testing
import Bitcoin

struct DocumentationExamples {

    @Test func gettingStarted() async throws {
        // Generate a secret key, corresponding public key, hash and address.
        let secretKey = SecretKey()
        let publicKey = secretKey.publicKey
        let address = BitcoinAddress(publicKey)

        // # Prepare the Bitcoin service.

        // Instantiate a fresh Bitcoin service (regtest).
        let service = BitcoinService()

        // Create the genesis block.
        await service.createGenesisBlock()

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        for _ in 0 ..< 100 {
            await service.generateTo(publicKey)
        }

        // # Prepare our transaction.

        // Grab block 1's coinbase transaction and output.
        let fundingTx = await service.blockTransactions[1][0]
        let prevout = fundingTx.outputs[0]

        // Create a new transaction spending from the previous transaction's outpoint.
        let unsignedInput = TransactionInput(outpoint: fundingTx.outpoint(0))

        // Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
        let spendingTx = BitcoinTransaction(
            inputs: [unsignedInput],
            outputs: [address.output(100)])

        // # We now need to sign the transaction using our secret key.

        let signer = TransactionSigner(transaction: spendingTx, prevouts: [prevout])
        let signedTx = signer.sign(input: 0, with: secretKey)

        // # We can verify that the transaction was signed correctly.

        // Make sure the transaction was signed correctly by verifying the scripts.
        let isVerified = signedTx.verifyScript(prevouts: [prevout])

        #expect(isVerified)
        // Yay! Our transaction is valid.

        // # Now we're ready to submit our signed transaction to the mempool.

        // Submit the signed transaction to the mempool.
        await service.addTransaction(signedTx)

        // The mempool should now contain our transaction.
        let mempoolBefore = await service.mempool.count
        #expect(mempoolBefore == 1)

        // # After confirming the transaction was accepted we can mine a block and get it confirmed.

        // Let's mine another block to confirm our transaction.

        // In this case we can re-use the address we created before.
        let publicKeyHash = Data(Hash160.hash(data: publicKey.data))

        // Minde to the public key hash
        await service.generateTo(publicKeyHash)

        // The mempool should now be empty.
        let mempoolAfter = await service.mempool.count
        #expect(mempoolAfter == 0)

        // # Finally let's make sure the transaction was confirmed in a block.

        let blocks = await service.headers.count
        #expect(blocks == 102)

        let lastBlock = await service.blockTransactions.last!
        // Verify our transaction was confirmed in a block.

        #expect(lastBlock[1] == signedTx)
        // Our transaction is now confirmed in the blockchain!
    }
}
