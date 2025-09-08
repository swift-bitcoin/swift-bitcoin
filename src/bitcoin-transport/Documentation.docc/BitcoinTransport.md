# ``BitcoinTransport``

@Metadata {
    @DisplayName("Bitcoin Transport")
    @TitleHeading("Swift Bitcoin framework")
}

Bitcoin transport layer, also known as the peer-to-peer or _wire_ protocol. Everything from the node service to messages to peer representation.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | [Base][base] | [Miniscript][miniscript] | [Wallet][wallet] | [PSBT][psbt] | [Blockchain][blockchain] | Transport | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

_BitcoinTransport_ handshake example:

```swift
import BitcoinTransport

let satoshi = NodeService(blockchain: satoshiChain, feeFilterRate: 2)
let halPeer = await satoshi.addPeer()
satoshiOut = await satoshi.getChannel(for: halPeer).makeAsyncIterator()

let halChain = BlockchainService()
await halChain.start()

let hal = NodeService(blockchain: halChain, feeFilterRate: 3)
let satoshiPeer = await hal.addPeer(incoming: false)
halOut = await hal.getChannel(for: satoshiPeer).makeAsyncIterator()

// … --(version)->> Satoshi
let messageHS0_version = NetworkMessage(.version, payload: VersionMessage().data)

try await satoshi.processMessage(messageHS0_version, from: halPeer)

// Satoshi --(version)->> …
_ = try #require(await satoshi.popMessage(halPeer))

// Satoshi --(wtxidrelay)->> …
_ = try #require(await satoshi.popMessage(halPeer))

// Satoshi --(sendaddrv2)->> …
_ = try #require(await satoshi.popMessage(halPeer))

let messageHS1_sendaddrv2 = NetworkMessage(.sendaddrv2)
try await satoshi.processMessage(messageHS1_sendaddrv2, from: halPeer)

let messageHS2_wtxidrelay = NetworkMessage(.wtxidrelay)
try await satoshi.processMessage(messageHS2_wtxidrelay, from: halPeer)

// Satoshi --(verack)->> …
_ = try #require(await satoshi.popMessage(halPeer))

let messageHS3_verack = NetworkMessage(.verack)
try await satoshi.processMessage(messageHS3_verack, from: halPeer)

// Satoshi --(sendcmpct)->> …
_ = try #require(await satoshi.popMessage(halPeer))

// Satoshi --(ping)->> …
_ = try #require(await satoshi.popMessage(halPeer))

// Satoshi --(feefilter)->> …
_ = try #require(await satoshi.popMessage(halPeer))

await halChain.stop()
```

## Topics

### Essentials

- ``NodeService``
- ``NodeParams``
- ``NodeState``
- ``PeerState``
- ``NetworkMessage``
- ``MessageCommand``
- <doc:Design>

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
