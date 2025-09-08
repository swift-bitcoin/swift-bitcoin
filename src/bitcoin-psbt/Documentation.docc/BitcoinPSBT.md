# ``BitcoinPSBT``

@Metadata {
    @DisplayName("Bitcoin PSBT")
    @TitleHeading("Swift Bitcoin framework")
}

Bitcoin PSBT (Partially Signed Bitcoin Transaction) corresponds to the implementation of BIP174, BIP370 and others.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | [Base][base] | [Miniscript][miniscript] | [Wallet][wallet] | PSBT | [Blockchain][blockchain] | [Transport][transport] | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

_BitcoinPSBT_ example:

```swift
import BitcoinPSBT

// Creator
// `tx` is a multisig transaction with with P2SH and P2SH-P2WSH inputs and 2 outputs.
let psbt = try PartiallySignedTx(tx)

// Updater 1
// …
psbt.update(input: 0, fund1)
psbt.update(input: 0, redeemScript: redeem0)
psbt.update(input: 0, pubkey0, path0)
psbt.update(input: 0, pubkey1, path1)

psbt.update(input: 1, fund0.outs[1])
psbt.update(input: 1, redeemScript: redeem1)
psbt.update(input: 1, witnessScript: witness)
psbt.update(input: 1, pubkey2, path2)
psbt.update(input: 1, pubkey3, path3)

psbt.update(out: 0, pubkey4, path4)
psbt.update(out: 1, pubkey5, path5)

// Second updater
// …
psbt.update(input: 0, SighashType.all)
psbt.update(input: 1, SighashType.all)

// Signer
// …
try psbt.sign(input: 0, using: secretKey0)
try psbt.sign(input: 1, using: secretKey1)

// Second signer
// …
try psbt.sign(input: 0, using: secretKey0)
try psbt.sign(input: 1, using: secretKey1)

// Combiner
// …
psbt.combine(with: psbt2)

// Finalizer
// …
psbt.finalize()

// Extractor
// …
let tx = psbt.extractTx()
```

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
