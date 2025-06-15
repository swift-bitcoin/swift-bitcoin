# Getting Started

Swift Bitcoin let's you integrate the different capabilities of the Bitcoin protocol into your own product.

## Overview

To start using Swift Bitcoin as a library just add it as a dependency to your package manifest.

For instructions on running a node please refer to <doc:Running> instead.

## Preparation

### Add the package

In your `Package.swift` dependencies add the package's URL `https://github.com/swift-bitcoin/swift-bitcoin`.

### Import the framework

To begin just import `Bitcoin`.

```swift
import Bitcoin
```

## Mine a transaction

In this example we will spin up a test Bitcoin server and use it to mine a transaction.

Let's start by generating a key pair and derive an address for our test.

```swift
// Generate a secret key, corresponding public key, hash and address.
let secretKey = SecretKey()
let pubkey = secretKey.pubkey
let address = LegacyAddress(pubkey)
```

Prepare the Blockchain service.

```swift
// Create a fresh blockchain service instance (on regtest).
let blockchain = BlockchainService()
await blockchain.start()

// Mine 100 blocks so block 1's coinbase output reaches maturity.
for _ in 0 ..< 100 {
    await blockchain.generateTo(address.script)!
}
```

Prepare our transaction.

```swift
// Grab block 1's coinbase transaction and output.
let fundingTx = await blockchain.blocks[1].txs[0]
let prevout = fundingTx.outs[0]

// Create a new transaction spending from the previous transaction's outpoint.
let unsignedInput = Transaction.Input(outpoint: fundingTx.outpoint(0))

// Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
let spendingTx = Transaction(ins: [unsignedInput], outs: [address.out(100)])
```

We now need to sign the transaction using our secret key.

```swift
let signer = TransactionSigner(tx: spendingTx, prevouts: [prevout])
let signedTx = signer.sign(input: 0, with: secretKey)
```

We can verify that the transaction was signed correctly.

```swift
// Make sure the transaction was signed correctly by verifying the scripts.
let isVerified = signedTx.verifyScript(prevouts: [prevout])

#expect(isVerified)
// Yay! Our transaction is valid.
```

Now we're ready to submit our signed transaction to the mempool.

```swift
// Submit the signed transaction to the mempool.
try await blockchain.addTransaction(signedTx)

// The mempool should now contain our transaction.
#expect(await blockchain.mempool.count == 1)
```

After confirming the transaction was accepted we can mine a block and get it confirmed.

```swift
// Let's mine another block to confirm our transaction.

// In this case we can re-use the address we created before.
let pubkeyHash = Data(Hash160.hash(data: pubkey.data))

// Mine one block to our address.
let lastBlock = await blockchain.generateTo(address.script)!

// The mempool should now be empty.
#expect(await blockchain.mempool.count == 0)
```

Finally let's make sure the transaction was confirmed in a block.

```swift
let blocks = await blockchain.blocks.count
#expect(blocks == 102)

let lastBlock = await blockchain.blocks.last!
// Verify our transaction was confirmed in a block.

#expect(lastBlock.txs[1] == signedTx)
// Our transaction is now confirmed in the blockchain!

await blockchain.stop()
```

We have effectively recreated the entire transaction lifecycle.
