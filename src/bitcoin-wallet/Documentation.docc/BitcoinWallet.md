# ``BitcoinWallet``

@Metadata {
    @DisplayName("Bitcoin Wallet")
    @TitleHeading("Swift Bitcoin framework")
}

Generate and decode Bitcoin addresses. Manage mnemonic seeds and derive Hierarchically Deterministic (HD) keys.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | [Base][base] | [Miniscript][miniscript] | Wallet | [PSBT][psbt] | [Blockchain][blockchain] | [Transport][transport] | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

Use BitcoinWallet to generate addresses from public keys or scripts and to decode either legacy, segregated witness or taproot addresses.

Create private (_xpriv_) and public (_xpub_) master keys from BIP32 seeds and use them to derive output keys. Manage BIP39 mnemonic phrases in multiple languages.

Sample code: _Bob sends 50 satoshis to Alice_.

```swift
// Bob gets paid.
let bobsSecretKey = SecretKey()
let bobsAddress = LegacyAddress(bobsSecretKey)

// The funding transaction, sending money to Bob.
let fundingTx = Transaction(ins: [.init(outpoint: .coinbase)], outs: [
    bobsAddress.out(100) // 100 satoshis
])

// Alice generates an address to give Bob.

let alicesSecretKey = SecretKey()
let alicesAddress = LegacyAddress(alicesSecretKey)

// Bob constructs, sings and broadcasts a transaction which pays Alice at her address.

// The spending transaction by which Bob sends money to Alice
let spendingTx = Transaction(ins: [
    .init(outpoint: fundingTx.outpoint(0)),
], outs: [
    alicesAddress.out(50) // 50 satoshis
])

// Sign the spending transaction.
let prevouts = [fundingTx.outs[0]]
let signer = TransactionSigner(
    tx: spendingTx, prevouts: prevouts, sighashType: .all
)
let signedTx = signer.sign(input: 0, with: bobsSecretKey)

// Verify transaction signatures.
let result = signedTx.verifyScript(prevouts: prevouts)
#expect(result)
```

## Topics

### Addresses

- ``Address``
- ``LegacyAddress``
- ``SegwitAddress``
- ``TaprootAddress``
- ``AddressProtocol``

### Hierarchically Deterministic (HD) extended keys

- ``ExtendedKey``
- ``DerivationPath``

### Mnemonic

- ``MnemonicPhrase``

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
