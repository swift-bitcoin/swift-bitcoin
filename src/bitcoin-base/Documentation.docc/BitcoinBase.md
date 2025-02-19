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

let previousTx: BitcoinTx = …
let prevout = previousTx.outs[0]
let outpoint = previousTx.outpoint(0)

// Create a new transaction spending from the previous transaction's outpoint.
let unsignedInput = TxInput(outpoint: outpoint)

// Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
let unsignedTx = BitcoinTx(
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
let sighash = unsignedTx.signHash(sighashType: .all, txIn: 0, prevout: prevout, scriptCode: prevout.script.data)
…
```

## Topics

### Essentials

- ``BitcoinTx``
- ``BitcoinScript``
- ``TxIn``
- ``TxOut``
- ``SigVersion``
- ``SighashType``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [RPC Library][rpc]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[crypto]: https://swiftbitcoin.org/docs/crypto/documentation/bitcoincrypto/
[wallet]: https://swiftbitcoin.org/docs/wallet/documentation/bitcoinwallet/
[blockchain]: https://swiftbitcoin.org/docs/blockchain/documentation/bitcoinblockchain/
[transport]: https://swiftbitcoin.org/docs/transport/documentation/bitcointransport/
[rpc]: https://swiftbitcoin.org/docs/rpc/documentation/bitcoinrpc/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
