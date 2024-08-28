# ``BitcoinUtility``

@Metadata {
    @DisplayName("Bitcoin Utility (bcutil)")
    @TitleHeading("Swift Bitcoin Tool")
}

Use the `bcutil` command control a running Bitcoin node instance or perform off-chain operations.

## Overview

> Swift Bitcoin: This tool is part of the [Swift Bitcoin](https://swift-bitcoin.github.io/docc/documentation/bitcoin/) suite.

To connect to a running node instance and find out its status use the `node` subcommand.

```sh
bcutil node status
```

Use `--help` to find out about other subcommands and general usage.

## Topics

### Essentials

- ``Node``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[crypto]: https://swift-bitcoin.github.io/docc/crypto/documentation/bitcoincrypto/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
