# ``BitcoinMiniscript``

@Metadata {
    @DisplayName("Bitcoin Miniscript")
    @TitleHeading("Swift Bitcoin Library")
}

_Miniscript_ is a language for writing (a subset of) Bitcoin Scripts in a structured way, enabling analysis, composition, generic signing and more. Bitcoin Miniscript provides a DSL with all the checks and guarantees of Miniscript performed at compile-time.

## Overview

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

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Miniscript Library][miniscript]
- [Wallet Library][wallet]
- [PSBT Library][psbt]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [Bitcoin Utility (bcutil) Command][bcutil]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swiftbitcoin.org/docs/documentation/bitcoin/
[crypto]: https://swiftbitcoin.org/docs/crypto/documentation/bitcoincrypto/
[base]: https://swiftbitcoin.org/docs/base/documentation/bitcoinbase/
[miniscript]: https://swiftbitcoin.org/docs/miniscript/documentation/bitcoinminiscript/
[wallet]: https://swiftbitcoin.org/docs/wallet/documentation/bitcoinwallet/
[psbt]: https://swiftbitcoin.org/docs/psbt/documentation/bitcoinpsbt/
[blockchain]: https://swiftbitcoin.org/docs/blockchain/documentation/bitcoinblockchain/
[transport]: https://swiftbitcoin.org/docs/transport/documentation/bitcointransport/
[bcnode]: https://swiftbitcoin.org/docs/bcnode/documentation/bitcoinnode/
[bcutil]: https://swiftbitcoin.org/docs/bcutil/documentation/bitcoinutility/
