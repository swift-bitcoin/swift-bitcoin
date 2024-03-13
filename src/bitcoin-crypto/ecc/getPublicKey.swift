import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func getPublicKey(secretKey secretKeyData: Data, compress: Bool = true) -> Data {

    let secretKey = [UInt8](secretKeyData)

    var pubKey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubKey, secretKey) != 0 else {
        preconditionFailure()
    }

    var pubKeyBytes = [UInt8](repeating: 0, count: compress ? compressedKeySize : uncompressedKeySize)
    var pubKeyBytesCount = pubKeyBytes.count
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &pubKeyBytes, &pubKeyBytesCount, &pubKey, UInt32(compress ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(compress && pubKeyBytesCount == compressedKeySize || (!compress && pubKeyBytesCount == uncompressedKeySize))

    return Data(pubKeyBytes)
}
