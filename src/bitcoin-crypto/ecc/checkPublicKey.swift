import Foundation
import LibSECP256k1

// TODO: Consider expanding this technique to other C function wrappers.

/// Checks that a public key is valid.
public func checkPublicKey(_ publicKey: Data) -> Bool {
    // Alternatively `publicKey.withContiguousStorageIfAvailable { … }` can be sued.
    let publicKey = [UInt8](publicKey)
    var parsedPublicKey = secp256k1_pubkey()
    return secp256k1_ec_pubkey_parse(secp256k1_context_static, &parsedPublicKey, publicKey, publicKey.count) != 0
}
