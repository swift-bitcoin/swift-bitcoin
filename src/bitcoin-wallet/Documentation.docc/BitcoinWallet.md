# ``BitcoinWallet``

@Metadata {
    @DisplayName("BitcoinWallet")
    @TitleHeading("Swift Bitcoin Library")
}

Generate and decode Bitcoin addresses. Manage mnemonic seeds and derive Hierarchically Deterministic (HD) keys.

## Overview

Use BitcoinWallet to generate addresses from public keys or scripts and to decode either legacy, segregated witness or taproot addresses.

Create private (_xpriv_) and public (_xpub_) master keys from BIP32 seeds and use them to derive output keys. Manage BIP39 mnemonic phrases in multiple languages.

Sample code: _Bob sends 50 satoshis to Alice_.

```swift
// Bob gets paid.
let bobsSecretKey = SecretKey()
let bobsAddress = LegacyAddress(bobsSecretKey)

// The funding transaction, sending money to Bob.
let fundingTx = BitcoinTx(ins: [.init(outpoint: .coinbase)], outs: [
    bobsAddress.out(100) // 100 satoshis
])

// Alice generates an address to give Bob.

let alicesSecretKey = SecretKey()
let alicesAddress = LegacyAddress(alicesSecretKey)

// Bob constructs, sings and broadcasts a transaction which pays Alice at her address.

// The spending transaction by which Bob sends money to Alice
let spendingTx = BitcoinTx(ins: [
    .init(outpoint: fundingTx.outpoint(0)),
], outs: [
    alicesAddress.out(50) // 50 satoshis
])

// Sign the spending transaction.
let prevouts = [fundingTx.outs[0]]
let signer = TxSigner(
    tx: spendingTx, prevouts: prevouts, sighashType: .all
)
let signedTx = signer.sign(txIn: 0, with: bobsSecretKey)

// Verify transaction signatures.
let result = signedTx.verifyScript(prevouts: prevouts)
#expect(result)
```

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
- [RPC Library][rpc]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[crypto]: https://swiftbitcoin.org/docs/crypto/documentation/bitcoincrypto/
[base]: https://swiftbitcoin.org/docs/base/documentation/bitcoinbase/
[blockchain]: https://swiftbitcoin.org/docs/blockchain/documentation/bitcoinblockchain/
[transport]: https://swiftbitcoin.org/docs/transport/documentation/bitcointransport/
[rpc]: https://swiftbitcoin.org/docs/rpc/documentation/bitcoinrpc/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
