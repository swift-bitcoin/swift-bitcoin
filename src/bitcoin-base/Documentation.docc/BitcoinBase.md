# ``BitcoinBase``

@Metadata {
    @DisplayName("Bitcoin Base")
    @TitleHeading("Swift Bitcoin framework")
}

Basic elements of the Bitcoin protocol, namely transactions and scripts.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | Base | [Miniscript][miniscript] | [Wallet][wallet] | [PSBT][psbt] | [Blockchain][blockchain] | [Transport][transport] | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

_BitcoinBase_ basic usage:

```swift
import BitcoinBase

let previousTx: Transaction = …
let prevout = previousTx.outs[0]
let outpoint = previousTx.outpoint(0)

// Create a new transaction spending from the previous transaction's outpoint.
let unsignedInput = Transaction.Input(outpoint: outpoint)

// Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
let unsignedTx = Transaction(
    ins: [unsignedInput],
    outs: [
        .init(value: 49_99_999_000, script: .init([
            .dup,
            .hash160,
            .pushBytes(pubkeyHash),
            .equalVerify,
            .checkSig
        ]))
    ])

// Sign the transaction by first calculating the signature hash.
let sighash = SignatureHash(tx: unsignedTx, input: 0, sighashType: .all, scriptCode: prevout.script.data)
…
```

## Topics

### Essentials

- ``Transaction``
- ``Script``
- ``Transaction/Input``
- ``TransactionOutput``
- ``SigVersion``
- ``SighashType``

<!-- links -->

[bitcoin]: /documentation/bitcoin
[crypto]: /documentation/bitcoincrypto
[base]: /documentation/bitcoinbase
[miniscript]: /documentation/bitcoinminiscript
[wallet]: /documentation/bitcoinwallet
[psbt]: /documentation/bitcoinpsbt
[blockchain]: /documentation/bitcoinblockchain
[transport]: /documentation/bitcointransport
[rpc]: /documentation/bitcoinrpc
[bcnode]: /documentation/bitcoinnode
[bcutil]: /documentation/bitcoinutility
