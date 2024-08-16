import Foundation
import LibSECP256k1

public func checkXOnlyPublicKey(_ publicKeyData: Data) -> Bool {
    let publicKeyData = [UInt8](publicKeyData)
    var publicKey = secp256k1_xonly_pubkey()
    let result = secp256k1_xonly_pubkey_parse(secp256k1_context_static, &publicKey, publicKeyData)
    return result != 0
}
