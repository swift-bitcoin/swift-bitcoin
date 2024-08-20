import Foundation
import LibSECP256k1

/// These extensions are not currently used although they might be useful some day.
private extension SecretKey {

    /// Requires global signing context to be initialized.
    func getPublicKey(compress: Bool = true) -> Data {

        let secretKey = [UInt8](data)

        var pubkey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKey) != 0 else {
            preconditionFailure()
        }

        var publicKeyBytes = [UInt8](repeating: 0, count: compress ? compressedPublicKeySize : uncompressedPublicKeySize)
        var publicKeyBytesCount = publicKeyBytes.count
        guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &publicKeyBytes, &publicKeyBytesCount, &pubkey, UInt32(compress ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
            preconditionFailure()
        }
        assert(compress && publicKeyBytesCount == compressedPublicKeySize || (!compress && publicKeyBytesCount == uncompressedPublicKeySize))

        return Data(publicKeyBytes)
    }

    /// Gets the internal (x-only) public key for the specified secret key. Requires global signing context to be initialized.
    func getXOnlyPublicKey() -> Data {

        let secretKey = [UInt8](data)

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
}
