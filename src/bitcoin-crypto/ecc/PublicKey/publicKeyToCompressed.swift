import Foundation
import LibSECP256k1

public func publicKeyToCompressed(_ publicKeyData: Data) -> Data {
    let publicKeyData = [UInt8](publicKeyData)

    var publicKey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &publicKey, publicKeyData, publicKeyData.count) != 0 else {
        preconditionFailure()
    }
    var compressedPublicKeyBytes = [UInt8](repeating: 0, count: compressedPublicKeySize)
    var compressedPublicKeyBytesCount = compressedPublicKeyBytes.count
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &compressedPublicKeyBytes, &compressedPublicKeyBytesCount, &publicKey, UInt32(SECP256K1_EC_COMPRESSED)) != 0 else {
        preconditionFailure()
    }
    assert(compressedPublicKeyBytesCount == compressedPublicKeySize)

    return Data(compressedPublicKeyBytes)
}
