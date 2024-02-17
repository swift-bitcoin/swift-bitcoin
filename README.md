# Swift Bitcoin

[Blog](https://swift-bitcoin.github.io)
[Documentation](https://swift-bitcoin.github.io/docc/documentation/bitcoin/)

Swift Bitcoin is a [Bitcoin](https://bitcoin.org/bitcoin.pdf) network client written entirely in [Swift](https://www.swift.org/documentation/) with minimal[^1] third-party dependencies. It fully implements the Bitcoin protocol and exposes it as a framework for Swift application development on every [supported platform](https://www.swift.org/platform-support/). In addition to the [API](https://swift-bitcoin.github.io/docc/documentation/bitcoin/) there's command-line tools for [launching](https://swift-bitcoin.github.io/docc/bcnode/documentation/bcnode/) a peer-to-peer node, [interfacing](https://swift-bitcoin.github.io/docc/bcutil/documentation/bcutil/) with it using RPC and performing advanced off-chain wallet and cryptographic operations.

The library provides full support for bitcoin [transactions](https://en.bitcoin.it/wiki/Transaction), [SCRIPT](https://en.bitcoin.it/wiki/Script), [segregated witness](https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki),
[Schnorr signatures](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki), [taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki), [tapscript](https://github.com/bitcoin/bips/blob/master/bip-0342.mediawiki) and more.

The goal is to make Swift Bitcoin the most comprehensive SDK for bitcoin in Swift with features like mempool management, block mining and connectivity via the bitcoin protocol.

# Development Roadmap

We want the library to be fully tested from the beginning. When available we will use test vectors from the BIPs and reference implementations or port tests directly from [Bitcoin Core](https://bitcoincore.org).

This implies a slow and steady progress but the end result will be a secure and robust product on which developers can base their solutions.

Below is a rough roadmap of the order in which features could be integrated.

- Full transaction model with script, lock-time, input sequence and witness.
- Transaction serialization and deserialization.
- SCRIPT interpreter loop.
- Transaction signature hash, signature [signature hash types](https://river.com/learn/terms/s/sighash-flag/) and signature generation (ECDSA).
- [`OP_CHECKSIG`](https://en.bitcoin.it/wiki/OP_CHECKSIG).
- Transaction verifying for Pay-to-Public-Key (`P2PK`) and Pay-to-Public-Key-Hash (`P2PKH`).
- [`OP_RIPEMD160`](https://en.bitcoin.it/wiki/RIPEMD-160), `OP_SHA256`, `OP_HASH256`, `OP_HASH160` and other cryptographic operations.
- `Base58` and [`Base58Check`](https://en.bitcoin.it/wiki/Base58Check_encoding) address encoding/decoding.
- [`OP_CHECKMULTISIG`](https://en.bitcoin.it/wiki/OP_CHECKMULTISIG).
- Transaction verifying [`P2SH`](https://github.com/bitcoin/bips/blob/master/bip-0016.mediawiki).
- [Relative lock-time](https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki).
- [`OP_CHECKSEQUENCEVERIFY`](https://github.com/bitcoin/bips/blob/master/bip-0112.mediawiki).
- [`OP_CHECKLOCKTIMEVERIFY`](https://github.com/bitcoin/bips/blob/master/bip-0065.mediawiki).
- [`NULLDUMMY`](https://en.bitcoin.it/wiki/BIP_0147).
- Other script operations (arithmetic, stack, …).
- [Segwit](https://github.com/bitcoin/bips/blob/master/bip-0143.mediawiki) transaction verifying `P2WPKH`, `P2WSH`, `P2SH-P2WPKH`, `P2SH-P2WSH`.
- [`Bech32`](https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki) address encoding/decoding.
- Transaction Schnorr signature generation.
- Pay-to-Taproot [`P2TR`](https://github.com/bitcoin/bips/blob/master/bip-0086.mediawiki) (key-hash spends only).
- Transaction signing for all standard scripts.
- [`Bech32m`](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki) address encoding/decoding.
- `OP_CHECKSIGADD` (witness V1 script).
- Tapscript transactions.

[^1]: There is one dependency on Bitcoin's official [secp256k1](https://github.com/bitcoin-core/secp256k1) library for critical elliptic curve cryptography operations.
