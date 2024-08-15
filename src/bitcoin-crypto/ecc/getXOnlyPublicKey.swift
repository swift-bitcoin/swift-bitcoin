import Foundation
import LibSECP256k1

/// Gets the internal (x-only) public key for the specified secret key. Requires global signing context to be initialized.
public func getXOnlyPublicKey(secretKey secretKeyData: Data) -> Data {

    let secretKey = [UInt8](secretKeyData)

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKey) != 0 else {
        preconditionFailure()
    }

    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &xonlyPubkey, nil, &keypair) != 0 else {
        preconditionFailure()
    }

    var xonlyPubkeyBytes = [UInt8](repeating: 0, count: 32)
    guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &xonlyPubkeyBytes, &xonlyPubkey) != 0 else {
        preconditionFailure()
    }

    return Data(xonlyPubkeyBytes)
}
