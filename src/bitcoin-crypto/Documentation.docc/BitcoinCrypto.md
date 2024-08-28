# ``BitcoinCrypto``

@Metadata {
    @DisplayName("Bitcoin Crypto")
    @TitleHeading("Swift Bitcoin Library")
}

Bitcoin cryptography helpers. ECC signing and verfying. Hash functions.

## Overview

Use this library to directly sign and verify messages and hashes.

_BitcoinCrypto_ usage example:

```swift
import BitcoinCrypto

// Generate a secret key, corresponding public key, hash and address.
let secretKey = SecretKey()
let publicKey = secretKey.publicKey
let publicKeyHash = hash160(publicKey.data)
…

// Obtain the signature using our secret key and append the signature hash type.
let signature = Signature(messageHash: sigHash, secretKey: secretKey, type: .ecdsa)
let signatureData = signature.data
…
```

## Topics

### Essentials

- ``SecretKey``
- ``PublicKey``
- ``Signature``
- ``hash256(_:)``
- ``hash160(_:)``
- ``Base58Encoder``
- ``Base58Decoder``
- ``Bech32Encoder``
- ``Bech32Decoder``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Base Library][base]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
[bcutil]: https://swift-bitcoin.github.io/docc/bcutil/documentation/bitcoinutility/
