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
- ``ECDSASignature``
- ``SchnorrSignature``
- ``RecoverableSignature``

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
- ``SHA256(tag:)``

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
- [Miniscript Library][miniscript]
- [Wallet Library][wallet]
- [PSBT Library][psbt]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [RPC Library][rpc]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[base]: https://swiftbitcoin.org/docs/base/documentation/bitcoinbase/
[miniscript]: https://swiftbitcoin.org/docs/miniscript/documentation/bitcoinminiscript/
[wallet]: https://swiftbitcoin.org/docs/wallet/documentation/bitcoinwallet/
[psbt]: https://swiftbitcoin.org/docs/psbt/documentation/bitcoinpsbt/
[blockchain]: https://swiftbitcoin.org/docs/blockchain/documentation/bitcoinblockchain/
[transport]: https://swiftbitcoin.org/docs/transport/documentation/bitcointransport/
[rpc]: https://swiftbitcoin.org/docs/rpc/documentation/bitcoinrpc/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
