[![Build Status](https://img.shields.io/github/actions/workflow/status/swift-bitcoin/swift-bitcoin/test.yml)](https://github.com/swift-bitcoin/swift-bitcoin/actions/workflows/test.yml)
[![Swift Server](https://img.shields.io/badge/Swift-Server-gray?&labelColor=F54A2A&logo=swift&logoColor=white)](https://www.swift.org/documentation/server/)
[![Documentation](https://img.shields.io/badge/DocC-docs-gray?&labelColor=blue&logo=swift&logoColor=white)](https://swiftbitcoin.org/docs/documentation/bitcoin/)
[![Swift Version](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswift-bitcoin%2Fswift-bitcoin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/swift-bitcoin/swift-bitcoin)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswift-bitcoin%2Fswift-bitcoin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/swift-bitcoin/swift-bitcoin)
[![GitHub License](https://img.shields.io/github/license/swift-bitcoin/swift-bitcoin)](LICENSE)

[![Blog](https://img.shields.io/badge/website-blog-yellow)](https://swiftbitcoin.org/)
[![X (formerly Twitter) Follow](https://img.shields.io/twitter/follow/SwiftBitcoinOrg)](https://x.com/SwiftBitcoinOrg)
[![OpenSats: Funded](https://img.shields.io/badge/%3E__OpenSats-funded-gray?labelColor=f97316)](https://opensats.org/blog/twelfth-wave-of-bitcoin-grants#swift-bitcoin)

![Swift Bitcoin](https://github.com/user-attachments/assets/e7f29e72-6aa9-4f2c-9ba0-1e2a973ee09b)

# Swift Bitcoin

Swift Bitcoin is a cross-platform fully-featured Bitcoin development framework for Swift projects. It includes a standalone network client daemon as well as a command line utility for on-chain and off-chain operations. Swift Bitcoin is written entirely in modern data-race safe Swift with minimal third-party dependencies.

## Usage as Library

To integrate Swift Bitcoin into your own project first add an entry to your `Package.swift` dependencies:

```swift
let package = Package( …
    dependencies: [ …
        .package(url: "https://github.com/swift-bitcoin/swift-bitcoin", branch: "develop") …
```

Make sure to also include a `Bitcoin` product reference in the specific target's dependencies:

```swift
… targets: [
    .target( …
        dependencies: [ …
            .product(name: "Bitcoin", package: "swift-bitcoin") …
```

On your Swift sources import the `Bitcoin` module:

```swift
import Bitcoin
```

Additional products/modules exist for specific areas of functionality:

- `BitcoinCrypto` - Cryptography, key management and encodings.
- `BitcoinBase` - Transactions and script interpretation.
- `BitcoinWallet` - Wallet, addresses, mnemonics and key derivation.
- `BitcoinBlockchain` - Blockchain services and memory pool.
- `BitcoinTransport` - Peer-to-peer protocol implementation.
- `BitcoinRPC` - Support for RPC (Remote Procedure Call).

All functionalities are included in the umbrella `Bitcoin` module.

Check out our [Getting Started](https://swiftbitcoin.org/docs/documentation/bitcoin/gettingstarted) guide to begin leveraging Swift Bitcoin's capabilities.

## Usage as Command Line Tool

### Run from Sources

From the project's root use `swift run bcnode` to start a Bitcoin Node instance with default settings.

Launch the Bitcoin Utility to perform off-chain operations or to control a running node instance. To query the node's status use `swift run bcutil status`.

See [Running](https://swiftbitcoin.org/docs/documentation/bitcoin/running) for additional information on how to invoke the CLI tools.

### Install with Mint

If you have [Mint](https://github.com/yonaskolb/Mint) on your system you can install Swift Bitcoin tools with:

    mint install swift-bitcoin/swift-bitcoin@develop

## Repository and Package Organization

This repository contains a single Swift Package which exposes a series of library and executable products: crypto, base, wallet, blockchain, transport, RPC, node and utility.

Refer to each module's [documentation](https://swiftbitcoin.org/docs/documentation/bitcoin/) to understand the exact functionality covered.

There's test targets defined for each of the modules which can all be run with `swift test`.

## Building and Testing

To build the project and run the command line tools use the `swift` command.

First make sure all tests are passing:

```bash
swift build --build-tests
swift test
```

See [Building](https://swiftbitcoin.org/docs/documentation/bitcoin/building) to learn how to generate a release build on multiple platforms.

## Technology Stack

Many of the latest features from the extended Swift Language ecosystem are leveraged by Swift Bitcoin to keep usability, performance and reliability at the highest possible level.

- Swift Package Manager
- C / C++ interoperability
- Async/await APIs
- Actors for mutable state isolation
- Non-Blocking I/O and service lifecycle
- Structured concurrency
- Data race safety
- Argument parser
- Swift Testing
- DocC documentation plugin
- Logging
- Typed throws
- Value semantics (virtually no `class` definitions)
- Swift Plugins

Going forward we would like to experiment with Swift Macros, Embedded Swift and `~Copyable` to bring the solution even closer to the cutting edge.

## Project Dependencies

Swift Bitcoin itself depends on Bitcoin Core's `libsecp256k1` as well as a reduced set of official Swift Language packages such as Swift Algorithms and Collections.

The transport and RPC modules depend on the open source SwiftNIO library by Apple which is also use for non-blocking file system access. For persistence Apple's fork of LMDB is used.

## Project status

Fully implemented: scripts, transactions, blocks, key generation, key derivation, mnemonics, signing, verifying, segwit, taproot, absolute/relative time locks, transaction/block validation, block persistence, initial block download, transaction/block relay, chain state, mempool, regtest consensus, address parsing and output generation.

Mostly implemented: wire protocol, RPC commands, mempool policy.

Make sure to check the project's [blog](https://swiftbitcoin.org) for the latest news and updates.

## Roadmap

The medium term focus is set on completing the wire protocol implementation for regtest ad well as relevant RPC commands from Bitcoin Core.

Following that the remaining BIPs associated to blocks and transport layer should be implemented. Standard-ness rules will need to be enforced and tested.

Medium-long term we'd like to be able to sync `testnet4` and with that launch our first beta.
