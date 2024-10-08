# Swift Bitcoin

[documentation](https://swift-bitcoin.github.io/docc/documentation/bitcoin/) ∙ [blog](https://swift-bitcoin.github.io)

Swift Bitcoin aims to become the first Bitcoin full node implementation and library written entirely in Swift.

## Repository organization

This repository contains a single Swift Package which exposes a series of library and executable products: crypto, base, wallet, blockchain, transport, RPC, node and utility.

Refer to each module's [documentation](https://swift-bitcoin.github.io/docc/documentation/bitcoin/) to understand the exact functionality they each cover.

## Use as library

To integrate Swift Bitcoin into your Swift project add it to your `Package.swift` dependencies:

```swift
let package = Package( …
    dependencies: [ …
        .package(url: "https://github.com/swift-bitcoin/swift-bitcoin", branch: "develop") …
```

Then select the appropriate modules as dependencies for a specific target:

```swift
… targets: [
    .target( …
        dependencies: [ …
            .product(name: "BitcoinWallet", package: "swift-bitcoin") …
```

The umbrella module `Bitcoin` will make the entire framework available to your project.

```swift
.product(name: "Bitcoin", package: "swift-bitcoin") 
``` 

In your source files make sure to import the corresponding module:

```swift
import Bitcoin
```

Refer to this [Getting Started](https://swift-bitcoin.github.io/docc/documentation/bitcoin/gettingstarted) documentation article to learn about some of the library's capabilities.

## Building and running

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

Refer to this [Building](https://swift-bitcoin.github.io/docc/documentation/bitcoin/building) documentation article to learn how to produce a release build on multiple platforms.

## Technologies

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

Swift Bitcoin itself depends on Bitcoin Core's `libsecp256k1` as well as some official Swift Language packages that extend the standard library.

The transport component depends on the open source SwiftNIO library by Apple. 

## Project status

As of October 2024 the APIs for cryptography, hashing functions, encodings, transactions, scripting, verification, wallet addresses, key derivation and input signing are stable and tested.

Most if not all BIPs relating to transaction verification, SCRIPT and wallet have been implemented completely including official test vectors and test data borrowed from the Bitcoin Core project. This includes full segwit and taproot support.

Blockchain, mempool, coins view are working in-memory but their APIs have not yet been solidified.

At this time the peer-to-peer client is able to connect and perform an extended handshake, send and respond to pings and synchronize headers. It is not yet ready to fully synchronize against a testnet node or even a regtest node.

Make sure to check the project's [blog](https://swift-bitcoin.github.io) for the latest news and updates. 

## Roadmap

The medium term focus is set on completing the wire protocol implementation on regtest.

After that the remaining BIPs associated to blocks and transport layer should be implemented.

Longer term a persistence story would need to be spec'd out and implemented to start thinking about sync'ing testnet. 
