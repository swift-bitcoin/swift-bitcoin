# ``BitcoinTransport``

@Metadata {
    @DisplayName("Bitcoin Transport")
    @TitleHeading("Swift Bitcoin Library")
}

Bitcoin transport layer, also known as the peer-to-peer or _wire_ protocol. Everything from the node service to messages to peer representation.

## Overview

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
let messageHS0_version = BitcoinMessage(.version, payload: VersionMessage().data)

try await satoshi.processMessage(messageHS0_version, from: halPeer)

// Satoshi --(version)->> …
_ = try #require(await satoshi.popMessage(halPeer))

// Satoshi --(wtxidrelay)->> …
_ = try #require(await satoshi.popMessage(halPeer))

// Satoshi --(sendaddrv2)->> …
_ = try #require(await satoshi.popMessage(halPeer))

let messageHS1_sendaddrv2 = BitcoinMessage(.sendaddrv2)
try await satoshi.processMessage(messageHS1_sendaddrv2, from: halPeer)

let messageHS2_wtxidrelay = BitcoinMessage(.wtxidrelay)
try await satoshi.processMessage(messageHS2_wtxidrelay, from: halPeer)

// Satoshi --(verack)->> …
_ = try #require(await satoshi.popMessage(halPeer))

let messageHS3_verack = BitcoinMessage(.verack)
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
- ``NodeConfig``
- ``NodeState``
- ``PeerState``
- ``BitcoinMessage``
- ``MessageCommand``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [RPC Library][rpc]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[crypto]: https://swiftbitcoin.org/docs/crypto/documentation/bitcoincrypto/
[base]: https://swiftbitcoin.org/docs/base/documentation/bitcoinbase/
[wallet]: https://swiftbitcoin.org/docs/wallet/documentation/bitcoinwallet/
[blockchain]: https://swiftbitcoin.org/docs/blockchain/documentation/bitcoinblockchain/
[rpc]: https://swiftbitcoin.org/docs/rpc/documentation/bitcoinrpc/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
