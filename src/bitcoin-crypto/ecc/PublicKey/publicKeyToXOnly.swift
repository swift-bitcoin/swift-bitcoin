import Foundation
import LibSECP256k1

/// Gets the internal (x-only) public key for the specified EC public key.
public func publicKeyToXOnly(_ publicKeyData: Data) -> Data {
    let publicKeyBytes = [UInt8](publicKeyData)

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
        preconditionFailure()
    }

    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_from_pubkey(secp256k1_context_static, &xonlyPubkey, nil, &pubkey) != 0 else {
        preconditionFailure()
    }

    var xonlyPubkeyBytes = [UInt8](repeating: 0, count: 32)
    guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xonlyPubkeyBytes, &xonlyPubkey) != 0 else {
        preconditionFailure()
    }

    return Data(xonlyPubkeyBytes)
}
