# Getting Started

To start using Swift Bitcoin just add it as a dependency to your package manifest.

## Overview

Add the package `https://github.com/swift-bitcoin/swift-bitcoin` to your `Package.swift`.

### Import the framework

To begin just import `Bitcoin`.

```swift
import Bitcoin
```

### Build a transaction

We'll create a dummy transaction and inscribe it with _hello_ as coinbase data and _bye_ as return data burning the 50 bitcoin reward.

```swift
let coinbaseTransaction = Transaction(
    version: .v1, // Version 1 transaction.
    locktime: .init(0), // No time lock.
    inputs: [
        .init(
            // This is a coinbase transaction.
            outpoint: .init(
                transaction: String(repeating: "0", count: 64), // Transaction "00…0".
                output: 0xffffffff
            ),
            sequence: .init(0xffffffff), // Sequence set to maximum.
            script: .init([
                0x05, // OP_PUSHBYTES_5
                0x68, 0x65, 0x6c, 0x6c, 0x6f, // hello
            ])
        )
    ],
    outputs: [
        .init(
            value: 5_000_000_000, // 50 BTC
            script: .init([
                0x6a, // OP_RETURN
                0x62, 0x79, 0x65 // bye
            ])
        )
    ])
```
