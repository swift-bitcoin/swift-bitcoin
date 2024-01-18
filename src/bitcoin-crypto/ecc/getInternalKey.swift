import Foundation
import LibSECP256k1

/// Gets the internal (x-only) public key for the specified EC public key.
public func getInternalKey(publicKey publicKeyData: Data) -> Data {
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

/// Gets the internal (x-only) public key for the specified secret key. Requires global signing context to be initialized.
public func getInternalKey(secretKey secretKeyData: Data) -> Data {
    guard let eccSigningContext else { preconditionFailure() }

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
