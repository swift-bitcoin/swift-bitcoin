# ``BitcoinCrypto``

@Metadata {
    @DisplayName("BitcoinCrypto")
    @TitleHeading("Swift Bitcoin Library")
}

Elliptic curve cryptography, hash function library and Bitcoin-specific coders.

## Overview

Use BitcoinCrypto to perform Bitcoin-related cryptographic operations:

- Use public-key cryptography to create and evaluate ECDSA and Schnorr signatures.
- Generate any of the cryptographically secure hashes used by the Bitcoin Protocol.

Encode and decode binary data into and from strings using Base58 or Bech32 encoding.

## Topics

### Public-key cryptography

- ``SecretKey``
- ``PublicKey``
- ``Signature``

### Hash functions

- ``RIPEMD160``
- ``SipHash``
- ``Hash256``
- ``Hash160``
- ``PBKDF2``
- ``SHA1``
- ``SHA256``
- ``SHA512``
- ``HMAC``
- ``SHA256/init(tag:)``

### Data/string coders

- ``Base58Encoder``
- ``Base58Decoder``
- ``Bech32Encoder``
- ``Bech32Decoder``
- ``Base16Encoder``
- ``Base16Decoder``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Base Library][base]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [RPC Library][rpc]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[rpc]: https://swift-bitcoin.github.io/docc/rpc/documentation/bitcoinrpc/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
[bcutil]: https://swift-bitcoin.github.io/docc/bcutil/documentation/bitcoinutility/
