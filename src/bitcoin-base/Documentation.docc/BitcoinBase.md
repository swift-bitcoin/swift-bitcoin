# ``BitcoinBase``

@Metadata {
    @DisplayName("Bitcoin Base")
    @TitleHeading("Swift Bitcoin Library")
}

Basic elements of the Bitcoin protocol, namely transactions and scripts.

## Overview

_BitcoinBase_ basic usage:

```swift
import BitcoinBase

let previousTransaction: BitcoinTransaction = …
let previousOutput = previousTransaction.outputs[0]
let outpoint = previousTransaction.outpoint(0)!

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

// Sign the transaction by first calculating the signature hash.
let sigHash = unsignedTransaction.signatureHash(sighashType: .all, inputIndex: 0, previousOutput: previousOutput, scriptCode: previousOutput.script.data)
…
```

## Topics

### Essentials

- ``BitcoinTransaction``
- ``BitcoinScript``
- ``TransactionInput``
- ``TransactionOutput``
- ``SigVersion``
- ``SighashType``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[crypto]: https://swift-bitcoin.github.io/docc/crypto/documentation/bitcoincrypto/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
[bcutil]: https://swift-bitcoin.github.io/docc/bcutil/documentation/bitcoinutility/
