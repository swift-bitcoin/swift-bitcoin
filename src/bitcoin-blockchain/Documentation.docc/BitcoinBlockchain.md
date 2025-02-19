# ``BitcoinBlockchain``

@Metadata {
    @DisplayName("Bitcoin Blockchain")
    @TitleHeading("Swift Bitcoin Library")
}

Bitcoin service layer namely transaction blocks, block headers, transaction memory pool (_mempool_) and coins (UTXO set). 

## Overview

_BitcoinBlockchain_ usage example:

```swift
import BitcoinBlockchain

// Instantiate a fresh Bitcoin service (regtest).
let blockchain = BlockchainService()
await blockchain.start()

// Mine 100 blocks so block 1's coinbase output reaches maturity.
for _ in 0 ..< 100 {
    await service.generateTo(BitcoinScript.payToPubkeyHash(pubkey))
}
…

// Submit the signed transaction to the mempool.
await blockchain.addTx(signedTx)

// The mempool should now contain our transaction.
#expect(await blockchain.mempool.count == 1)

// Let's mine another block to confirm our transaction.

// In this case we can use the address we created before.

// Mine one block to our address.
let lastBlock = await blockchain.generateTo(address.script)!

// The mempool should now be empty.
#expect(await blockchain.mempool.count == 0)
…

#expect(await blockchain.blocks.count == 102)

let lastBlock = await blockchain.txs.last!
// Verify our transaction was confirmed in a block.

#expect(lastBlock[1] == signedTx)
// Our transaction is now confirmed in the blockchain!

await blockchain.stop()
```

## Topics

### Essentials

- ``TxBlock``
- ``BlockchainService``
- ``ConsensusParams``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Wallet Library][wallet]
- [Transport Library][transport]
- [RPC Library][rpc]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[crypto]: https://swiftbitcoin.org/docs/crypto/documentation/bitcoincrypto/
[base]: https://swiftbitcoin.org/docs/base/documentation/bitcoinbase/
[wallet]: https://swiftbitcoin.org/docs/wallet/documentation/bitcoinwallet/
[transport]: https://swiftbitcoin.org/docs/transport/documentation/bitcointransport/
[rpc]: https://swiftbitcoin.org/docs/rpc/documentation/bitcoinrpc/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
