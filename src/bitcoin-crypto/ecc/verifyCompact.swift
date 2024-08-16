import Foundation
import LibSECP256k1

public func verifyCompact(signature signatureData: Data, messageHash: Data, publicKey publicKeyData: Data) -> Bool {
    let signatureData = [UInt8](signatureData)
    let messageHash = [UInt8](messageHash)
    let publicKeyData = [UInt8](publicKeyData)

    precondition(signatureData.count == compactSignatureSize)
    precondition(messageHash.count == messageHashSize)
    precondition(publicKeyData.count == compressedPublicKeySize)

    var signature = secp256k1_ecdsa_signature()
    guard secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, &signature, signatureData) != 0 else {
        preconditionFailure()
    }

    var publicKey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &publicKey, publicKeyData, publicKeyData.count) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &signature, messageHash, &publicKey) != 0
}
