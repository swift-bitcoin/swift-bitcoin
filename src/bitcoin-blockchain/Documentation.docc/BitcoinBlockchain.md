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
let service = BitcoinService()

// Create the genesis block.
await service.createGenesisBlock()

// Mine 100 blocks so block 1's coinbase output reaches maturity.
for _ in 0 ..< 100 {
    await service.generateTo(publicKey)
}
…

// Submit the signed transaction to the mempool.
await service.addTransaction(signedTransaction)

// The mempool should now contain our transaction.
let mempoolBefore = await service.mempool.count
#expect(mempoolBefore == 1)

// Let's mine another block to confirm our transaction.

// In this case we can use the address we created before.

// Minde to the public key hash
await service.generateTo(publicKey)

// The mempool should now be empty.
let mempoolAfter = await service.mempool.count
#expect(mempoolAfter == 0)
…

let blocks = await service.headers.count
#expect(blocks == 102)

let lastBlock = await service.transactions.last!
// Verify our transaction was confirmed in a block.

#expect(lastBlock[1] == signedTransaction)
// Our transaction is now confirmed in the blockchain!
```

## Topics

### Essentials


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

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[crypto]: https://swift-bitcoin.github.io/docc/crypto/documentation/bitcoincrypto/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[rpc]: https://swift-bitcoin.github.io/docc/rpc/documentation/bitcoinrpc/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
[bcutil]: https://swift-bitcoin.github.io/docc/bcutil/documentation/bitcoinutility/
