import Foundation
import LibSECP256k1

public func validateInternalKey(_ internalKeyData: Data) -> Bool {
    let internalKey = [UInt8](internalKeyData)
    var xOnlyPubKey = secp256k1_xonly_pubkey()
    let result = secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xOnlyPubKey, internalKey)
    return result != 0
}
