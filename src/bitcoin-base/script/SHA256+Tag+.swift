// Reference only: not part of the SHA256Extras target (SwiftPM compiles only Sources/).
// Copy into the module that owns the protocol. Declaring the tags outside the library keeps
// protocol constants next to the code that defines them and avoids name clashes.

import BitcoinCrypto

//// BIP340 (Schnorr signatures)
//extension SHA256.Tag {
//    package static let bip340Challenge = Self("BIP0340/challenge")
//    package static let bip340Aux = Self("BIP0340/aux")
//    package static let bip340Nonce = Self("BIP0340/nonce")
//}

// BIP341 (Taproot)
extension SHA256.Tag {
    static let tapLeaf = Self("TapLeaf")
    static let tapBranch = Self("TapBranch")
    static let tapSighash = Self("TapSighash")
    static let tapTweak = Self("TapTweak")
}

// Usage:
//   let sighash = SHA256.Tag.tapSighash.hash(bytes: message.span.bytes)
//   var hasher = SHA256.Tag.tapLeaf.makeHasher()
