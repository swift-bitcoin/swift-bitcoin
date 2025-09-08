# ``BitcoinRPC``

@Metadata {
    @DisplayName("Bitcoin RPC")
    @TitleHeading("Swift Bitcoin framework")
}

Bitcoin RPC (Remote Procedure Call) contains the basic JSON-RPC types along with implementations for the various commands.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | [Base][base] | [Miniscript][miniscript] | [Wallet][wallet] | [PSBT][psbt] | [Blockchain][blockchain] | [Transport][transport] | RPC | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

_BitcoinRPC_ example:

```swift
import BitcoinRPC

let command = GetBlockchainInfoCommand(blockchain: satoshiChain)
let output = await command.run(.init(id: "1", method: "get-blockchain-info", params: nil))
let result = try #require(output.result)
guard case .string(let blockchainInfo) = result else { fatalError() }
print(blockchainInfo)

// {"blocks": 2, "hashes": ["0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206",    "23b822b7912cf1b96f1ec5bb07fba40fdd0e889b1f650662f2c0336db9220851"],"headers": 2}
```

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
