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

// Declare a PSBT with proprietary info. Serialize and parse again to see that all the information is in fact preserved.

let proprietaryInfo = [
    "satoshi".data(using: .utf8)! : [
        ProprietaryKey(type: 0, data: .init([0])) : Data([0, 0, 0]),
        ProprietaryKey(type: .max, data: .init([1, 2, 3])) : Data([1, 2, 3, 4, 5, 6])
    ],
    "hal".data(using: .utf8)! : [
        ProprietaryKey(type: 101, data: .init([0, 0 , 0])) : Data([1, 0, 1]),
        ProprietaryKey(type: 1, data: .init([1, 1, 1, 1])) : Data([2, 3, 4, 5, 6])
    ]
]
let fund0 = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 3)])
let fund1 = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [.init(value: 2), .init(value: 5)])
let tx = BitcoinTx(ins: [
    .init(outpoint: fund0.outpoint(0)),
    .init(outpoint: fund1.outpoint(1))
], outs: [
    .init(value: 1),
    .init(value: 2),
    .init(value: 4)
])
let psbt = PartiallySignedTx(tx: tx, proprietaryInfo: proprietaryInfo, ins: [
    .init(
        prevoutTx: fund0, proprietaryInfo: proprietaryInfo
    ), .init(
        prevoutTx: fund1, proprietaryInfo: proprietaryInfo
    )
], outs: [
    .init(proprietaryInfo: proprietaryInfo), .init(proprietaryInfo: proprietaryInfo), .init(proprietaryInfo: proprietaryInfo)
])
let psbtData = psbt.binaryData
let psbt2 = try PartiallySignedTx(binaryData: psbtData)
#expect(psbt == psbt2)
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
