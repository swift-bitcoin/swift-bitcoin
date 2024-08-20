import Foundation
import LibSECP256k1

public func verifyCompact(signature signatureData: Data, messageHash: Data, publicKey: PublicKey) -> Bool {
    let signatureBytes = [UInt8](signatureData)
    let messageHash = [UInt8](messageHash)
    let publicKeyBytes = [UInt8](publicKey.data)

    precondition(signatureData.count == compactSignatureSize)
    precondition(messageHash.count == messageHashSize)

    var signature = secp256k1_ecdsa_signature()
    guard secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, &signature, signatureBytes) != 0 else {
        preconditionFailure()
    }

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &signature, messageHash, &pubkey) != 0
}
