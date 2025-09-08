# ``BitcoinCrypto``

@Metadata {
    @DisplayName("Bitcoin Crypto")
    @TitleHeading("Swift Bitcoin framework")
}

Elliptic curve cryptography, hash function library and Bitcoin-specific coders.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | Crypto | [Base][base] | [Miniscript][miniscript] | [Wallet][wallet] | [PSBT][psbt] | [Blockchain][blockchain] | [Transport][transport] | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

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
