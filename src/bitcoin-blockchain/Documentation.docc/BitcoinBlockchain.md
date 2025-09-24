# ``BitcoinBlockchain``

@Metadata {
    @DisplayName("Bitcoin Blockchain")
    @TitleHeading("Swift Bitcoin framework")
}

Bitcoin service layer namely transaction blocks, block headers, transaction memory pool (_mempool_) and coins (UTXO set).

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | [Base][base] | [Miniscript][miniscript] | [Wallet][wallet] | [PSBT][psbt] | Blockchain | [Transport][transport] | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

_BitcoinBlockchain_ usage example:

```swift
import BitcoinBlockchain

// Instantiate a fresh Bitcoin service (regtest).
let blockchain = try await BlockchainService()

// Mine 100 blocks so block 1's coinbase output reaches maturity.
for _ in 0 ..< 100 {
    await service.generateTo(BitcoinScript.payToPubkeyHash(pubkey))
}
…

// Submit the signed transaction to the mempool.
await blockchain.addTransaction(signedTx)

// The mempool should now contain our transaction.
#expect(await blockchain.mempool.count == 1)

// Let's mine another block to confirm our transaction.

// In this case we can use the address we created before.

// Mine one block to our address.
let lastBlock = await blockchain.generateTo(address.script)!

// The mempool should now be empty.
#expect(await blockchain.mempool.count == 0)
…

#expect(await blockchain.headers == 101)

let lastBlock = await blockchain.txs.last!
// Verify our transaction was confirmed in a block.

#expect(lastBlock[1] == signedTx)
// Our transaction is now confirmed in the blockchain!
```

## Topics

### Essentials

- ``Block``
- ``BlockchainService``
- ``ConsensusParams``
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
