import Foundation
import LibSECP256k1

/// Checks that a public key is valid.
public func checkPublicKey(_ publicKeyData: Data) -> Bool {
    let publicKeyBytes = [UInt8](publicKeyData)

    var pubkey = secp256k1_pubkey()
    return secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0
}
