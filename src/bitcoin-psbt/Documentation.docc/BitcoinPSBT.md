# ``BitcoinPSBT``

@Metadata {
    @DisplayName("Bitcoin PSBT")
    @TitleHeading("Swift Bitcoin Library")
}

Bitcoin PSBT (Partially Signed Bitcoin Transaction) corresponds to the implementation of BIP174, BIP370 and others.

## Overview

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

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Miniscript Library][miniscript]
- [Wallet Library][wallet]
- [PSBT Library][psbt]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[crypto]: https://swiftbitcoin.org/docs/crypto/documentation/bitcoincrypto/
[base]: https://swiftbitcoin.org/docs/base/documentation/bitcoinbase/
[miniscript]: https://swiftbitcoin.org/docs/miniscript/documentation/bitcoinminiscript/
[wallet]: https://swiftbitcoin.org/docs/wallet/documentation/bitcoinwallet/
[psbt]: https://swiftbitcoin.org/docs/psbt/documentation/bitcoinpsbt/
[blockchain]: https://swiftbitcoin.org/docs/blockchain/documentation/bitcoinblockchain/
[transport]: https://swiftbitcoin.org/docs/transport/documentation/bitcointransport/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
