import Foundation
import LibSECP256k1

// TODO: Consider expanding this technique to other C function wrappers.

/// Checks that a public key is valid.
public func checkPublicKey(_ publicKeyData: Data) -> Bool {
    // Alternatively `publicKeyData.withContiguousStorageIfAvailable { … }` can be used.
    let publicKeyData = [UInt8](publicKeyData)
    var publicKey = secp256k1_pubkey()
    return secp256k1_ec_pubkey_parse(secp256k1_context_static, &publicKey, publicKeyData, publicKeyData.count) != 0
}
