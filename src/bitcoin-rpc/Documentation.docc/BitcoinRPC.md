# ``BitcoinRPC``

@Metadata {
    @DisplayName("Bitcoin RPC")
    @TitleHeading("Swift Bitcoin Library")
}

Bitcoin RPC (Remote Procedure Call) contains the basic JSON-RPC types along with implementations for the various commands.

## Overview

_BitcoinRPC_ example:

```swift
import BitcoinRPC

let command = GetBlockchainInfoCommand(bitcoinService: satoshiChain)
let output = await command.run(.init(id: "1", method: "get-blockchain-info", params: .none))
let result = try #require(output.result)
guard case .string(let blockchainInfo) = result else { fatalError() }
print(blockchainInfo)

/*
{"blocks": 2, "hashes": [    "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206",    "23b822b7912cf1b96f1ec5bb07fba40fdd0e889b1f650662f2c0336db9220851"
],"headers": 2}
*/
```

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[crypto]: https://swift-bitcoin.github.io/docc/crypto/documentation/bitcoincrypto/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
[bcutil]: https://swift-bitcoin.github.io/docc/bcutil/documentation/bitcoinutility/
