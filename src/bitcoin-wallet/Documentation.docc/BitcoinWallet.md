# ``BitcoinWallet``

@Metadata {
    @DisplayName("BitcoinWallet")
    @TitleHeading("Swift Bitcoin Library")
}

Generate and decode Bitcoin addresses. Manage mnemonic seeds and derive Hierarchically Deterministic (HD) keys.

## Overview

Use BitcoinWallet to generate addresses from public keys or scripts and to decode either legacy, segregated witness or taproot addresses.

Create private (_xpriv_) and public (_xpub_) master keys from BIP32 seeds and use them to derive output keys. Manage BIP39 mnemonic phrases in multiple languages.

## Topics

### Addresses

- ``BitcoinAddress``
- ``SegwitAddress``
- ``TaprootAddress``

### Hierarchically Deterministic (HD) extended keys

- ``ExtendedKey``

### Mnemonic

- ``MnemonicPhrase`` 

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[crypto]: https://swift-bitcoin.github.io/docc/crypto/documentation/bitcoincrypto/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/
[bcutil]: https://swift-bitcoin.github.io/docc/bcutil/documentation/bitcoinutility/
