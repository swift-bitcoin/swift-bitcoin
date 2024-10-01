# Getting Started

To start using Swift Bitcoin just add it as a dependency to your package manifest.

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
let publicKey = secretKey.publicKey
let publicKeyHash = Data(Hash160.hash(data: publicKey.data))
let address = BitcoinAddress(publicKey, mainnet: false).description
```

Prepare the Bitcoin service.

```swift
// Instantiate a fresh Bitcoin service (regtest).
let service = BitcoinService()

// Create the genesis block.
await service.createGenesisBlock()

// Mine 100 blocks so block 1's coinbase output reaches maturity.
for _ in 0 ..< 100 {
    await service.generateTo(publicKey)
}
```

Prepare our transaction.

```swift
// Grab block 1's coinbase transaction and output.
let previousTransaction = await service.blockTransactions[1][0]
let prevout = previousTransaction.outputs[0]
let outpoint = previousTransaction.outpoint(0)!

// Create a new transaction spending from the previous transaction's outpoint.
let unsignedInput = TransactionInput(outpoint: outpoint)

// Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
let unsignedTransaction = BitcoinTransaction(
    inputs: [unsignedInput],
    outputs: [
        .init(value: 49_99_999_000, script: .init([
            .dup,
            .hash160,
            .pushBytes(publicKeyHash),
            .equalVerify,
            .checkSig
        ]))
    ])
```

We now need to sign the transaction using our secret key.

```swift
// Sign the transaction by first calculating the signature hash.
let sighash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, prevout: prevout, scriptCode: prevout.script.data)

// Obtain the signature using our secret key and append the signature hash type.
let signature = Signature(hash: sighash, secretKey: secretKey)
let signatureData = signature.data + [SighashType.all.value]

// Sign our input by including the signature and public key.
let signedInput = TransactionInput(
    outpoint: unsignedInput.outpoint,
    sequence: unsignedInput.sequence,
    script: .init([
        .pushBytes(signatureData),
        .pushBytes(publicKey.data)
    ]),
    witness: unsignedInput.witness)

// Put the signed input back into the transaction.
let signedTransaction = BitcoinTransaction(
    version: unsignedTransaction.version,
    locktime: unsignedTransaction.locktime,
    inputs: [signedInput],
    outputs: unsignedTransaction.outputs)
```

We can verify that the transaction was signed correctly.

```swift
// Make sure the transaction was signed correctly by verifying the scripts.
let isVerified = signedTransaction.verifyScript(prevouts: [prevout])

#expect(isVerified)
// Yay! Our transaction is valid.
```

Now we're ready to submit our signed transaction to the mempool.

```swift
// Submit the signed transaction to the mempool.
await service.addTransaction(signedTransaction)

// The mempool should now contain our transaction.
let mempoolBefore = await service.mempool.count
#expect(mempoolBefore == 1)
```

After confirming the transaction was accepted we can mine a block and get it confirmed.

```swift
// Let's mine another block to confirm our transaction.

// In this case we can use the address we created before.

// Decode the address to get the public key hash.
let decodedPublicKeyHash = BitcoinAddress(address)!.hash
#expect(publicKeyHash == decodedPublicKeyHash)

// Minde to the public key hash
await service.generateTo(decodedPublicKeyHash)

// The mempool should now be empty.
let mempoolAfter = await service.mempool.count
#expect(mempoolAfter == 0)
```

Finally let's make sure the transaction was confirmed in a block.

```swift
let blocks = await service.headers.count
#expect(blocks == 102)

let lastBlock = await service.blockTransactions.last!
// Verify our transaction was confirmed in a block.

#expect(lastBlock[1] == signedTransaction)
// Our transaction is now confirmed in the blockchain!
```

We have effectively recreated the entire transaction lifecycle.
