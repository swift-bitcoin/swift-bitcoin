import Foundation
import LibSECP256k1

public func publicKeyToUncompressed(_ publicKeyData: Data) -> Data {
    let publicKeyData = [UInt8](publicKeyData)

    var publicKey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &publicKey, publicKeyData, publicKeyData.count) != 0 else {
        preconditionFailure()
    }
    var uncompressedPublicKeyBytes = [UInt8](repeating: 0, count: uncompressedPublicKeySize)
    var uncompressedPublicKeyBytesCount = uncompressedPublicKeyBytes.count
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &uncompressedPublicKeyBytes, &uncompressedPublicKeyBytesCount, &publicKey, UInt32(SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(uncompressedPublicKeyBytesCount == uncompressedPublicKeySize)

    return Data(uncompressedPublicKeyBytes)
}
