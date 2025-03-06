# Swift Bitcoin

[documentation](https://swiftbitcoin.org/docs/documentation/bitcoin/) ∙ [blog](https://swiftbitcoin.org)

Swift Bitcoin is both a fully-featured Bitcoin development framework and a standalone network client daemon plus utility written entirely in Swift.

## Usage as library

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

- `BitcoinCrypto` - Cryptography, key management and encdodings.
- `BitcoinBase` - Transactions and script interpretation. 
- `BitcoinWallet` - Wallet, addresses, mnemonics and key derivation.
- `BitcoinBlockchain` - Blockchain services and memory pool.
- `BitcoinTransport` - Peer-to-peer protocol implementation.
- `BitcoinRPC` - Support for RPC (Remote Procedure Call). 

All functionalities above are included in the umbrella `Bitcoin` module.

Check out our [Getting Started](https://swiftbitcoin.org/docs/documentation/bitcoin/gettingstarted) guide to begin leveraging some of Swift Bitcoin's capabilities. 

## Usage as command line tool and daemon

Use `swift run bcnode` to start a Bitcoin Node instance.

Use `swift run bcutil` to run the Bitcoin Utility which can query/control node instances and perform off-chain operations. 

See [Running](https://swiftbitcoin.org/docs/documentation/bitcoin/running) for additional information on how to invoke the CLI tools. 

## Repository and package organization

This repository contains a single Swift Package which exposes a series of library and executable products: crypto, base, wallet, blockchain, transport, RPC, node and utility.

Refer to each module's [documentation](https://swiftbitcoin.org/docs/documentation/bitcoin/) to understand the exact functionality covered.

There's test targets defined for each of the modules which can all be run with `swift test`.

## Building

To build the project and run the command line tools use the `swift` command.

First make sure all tests are passing:

```bash
swift build --build-tests
swift test
```

Now you can run any of the executable targets available.

The Bitcoin Utility `bcutil` tool provides a number of useful offline commands as well as being able to query and control a running node instance. Check out the tool's help menu for usage information:

```bash
swift run bcutil --help
```

The Bitcoin Node `bcnode` tool launches a fresh node instance listening to RPC commands from `bcutil node`. Check out the tool's help menu for usage information:

```bash
swift run bcnode --help
```

See [Building](https://swiftbitcoin.org/docs/documentation/bitcoin/building) to learn how to generate a release build on multiple platforms.

## Technology stack

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

Going forward we would like to experiment with Swift Macros, Swift Embedded and `~Copyable` to bring the solution even closer to the cutting edge.

## Project dependencies

Swift Bitcoin itself depends on Bitcoin Core's `libsecp256k1` as well as a reduced set of official Swift Language packages which extend the standard library.

The transport and RPC modules depend on the open source SwiftNIO library by Apple. 

## Project status

As of October 2024 the APIs for cryptography, hashing functions, encodings, transactions, scripting, verification, wallet addresses, key derivation and input signing are stable and tested.

Most if not all BIPs relating to transaction verification, SCRIPT and wallet have been implemented completely including official test vectors and test data borrowed from the Bitcoin Core project. This includes full segwit and taproot support.

Blockchain, mempool, coins view are working in-memory but their APIs have not yet been solidified.

At this time the peer-to-peer client is able to connect and perform an extended handshake, send and respond to pings and synchronize headers. It is not yet ready to fully synchronize against a testnet node or even a regtest node.

Make sure to check the project's [blog](https://swiftbitcoin.org) for the latest news and updates. 

## Roadmap

The medium term focus is set on completing the wire protocol implementation on regtest.

After that the remaining BIPs associated to blocks and transport layer should be implemented.

Longer term a persistence story would need to be spec'd out and implemented to start thinking about sync'ing testnet. 
