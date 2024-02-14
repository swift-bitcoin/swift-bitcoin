# Getting Started

To start using Swift Bitcoin just add it as a dependency to your package manifest.

## Preparation

### Add the package

In your `Package.swift` dependencies add the package's URL [https://github.com/swift-bitcoin/swift-bitcoin](https://github.com/swift-bitcoin/swift-bitcoin).

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
let secretKey = Wallet.createSecretKey() as Data
let publicKey = Wallet.getPublicKey(secretKey: secretKey)
let publicKeyHash = hash160(publicKey)
let address = try Wallet.getAddress(publicKey: publicKey, sigVersion: .base, network: .regtest)
```

Prepare the Bitcoin service.

```swift
// Instantiate a fresh Bitcoin service (regtest).
let service = BitcoinService()

// Create the genesis block.
await service.createGenesisBlock()

// Mine 100 blocks so block 1's coinbase output reaches maturity.
for _ in 0 ..< 100 {
    await service.generateTo(address)
}
```

Prepare our transaction.

```swift
// Grab block 1's coinbase transaction and output.
let previousTransaction = await service.blockchain[1].transactions[0]
let previousOutput = previousTransaction.outputs[0]
let outpoint = previousTransaction.outpoint(for: 0)!

// Create a new transaction spending from the previous transaction's outpoint.
let unsignedInput = TransactionInput(outpoint: outpoint, sequence: .final)

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
let sigHash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, previousOutput: previousOutput, scriptCode: previousOutput.script.data)

// Obtain the signature using our secret key and append the signature hash type.
let sig = signECDSA(message: sigHash, secretKey: secretKey) + [SighashType.all.value]

// Sign our input by including the signature and public key.
let signedInput = TransactionInput(
    outpoint: unsignedInput.outpoint,
    sequence: unsignedInput.sequence,
    script: .init([
        .pushBytes(sig),
        .pushBytes(publicKey)
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
if signedTransaction.verifyScript(previousOutputs: [previousOutput]) {
    // Yay! Our transaction is valid.
}
```

Now we're ready to submit our signed transaction to the mempool.

```swift
// Submit the signed transaction to the mempool.
await service.addTransaction(signedTransaction)

// The mempool should now contain our transaction.
let mempoolBefore = await service.mempool.count // 1
```

After confirming the transaction was accepted we can mine a block and get it confirmed.

```swift
// Let's mine another block to confirm our transaction.
await service.generateTo(address)

// The mempool should now be empty.
let mempoolAfter = await service.mempool.count // 0
```

Finally let's make sure the transaction was confirmed in a block.

```swift
let blocks = await service.blockchain.count // 102

let lastBlock = await service.blockchain.last!
// Verify our transaction was confirmed in a block.
if lastBlock.transactions[1] == signedTransaction {
    // Our transaction is now confirmed in the blockchain!
}
```

We have effectively recreated the entire transaction lifecycle.
