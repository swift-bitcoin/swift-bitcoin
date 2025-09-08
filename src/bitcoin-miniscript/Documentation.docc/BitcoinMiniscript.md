# ``BitcoinMiniscript``

@Metadata {
    @DisplayName("Bitcoin Miniscript")
    @TitleHeading("Swift Bitcoin framework")
}

_Miniscript_ is a language for writing (a subset of) Bitcoin Scripts in a structured way, enabling analysis, composition, generic signing and more. Bitcoin Miniscript provides a DSL with all the checks and guarantees of Miniscript performed at compile-time.

## Overview

> Swift Bitcoin modules: [Bitcoin (umbrella)][bitcoin] | [Crypto][crypto] | [Base][base] | Miniscript | [Wallet][wallet] | [PSBT][psbt] | [Blockchain][blockchain] | [Transport][transport] | [RPC][rpc] | [Utility (bcutil)][bcutil] | [Node (bcnode)][bcnode]

_BitcoinMiniscript_ example:

```swift
import BitcoinMiniscript

// The BOLT #3 received HTLC policy

let key1 = …, key 2…, key3…

// Remote key: key1; Local key: key2; Revocation: key3

// The Miniscript
let exp = AndOr(PK(key1), OrI(AndV(Vx(PKH(key2)), Hash160(key2HashData)), Older(1008)), PK(key3))

#expect(exp.description == "andor(pk(\(key1Hex)),or_i(and_v(v:pkh(\(key2Hex)),hash160(\(key2Hash))),older(1008)),pk(\(key3Hex)))")
let asm = BitcoinScript(exp.compiled).asm()
#expect(asm == "\(key1Hex) OP_CHECKSIG OP_NOTIF \(key3Hex) OP_CHECKSIG OP_ELSE OP_IF OP_DUP OP_HASH160 \(key2Hash) OP_EQUALVERIFY OP_CHECKSIGVERIFY OP_SIZE 20 OP_EQUALVERIFY OP_HASH160 \(key2Hash) OP_EQUAL OP_ELSE f003 OP_CHECKSEQUENCEVERIFY OP_ENDIF OP_ENDIF ")

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
