import Foundation
import LibSECP256k1

public func recoverPublicKey(message: Data, signature: Data) -> Data? {

    precondition(signature.count == recoverableSignatureSize) // throw?

    let hash = [UInt8](messageHash(message))

    let recid = Int32((signature[0] - 27) & 3)
    let comp = ((signature[0] - 27) & 4) != 0

    let signatureSansPrefix = [UInt8](signature[1...])
    var sig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_recoverable_signature_parse_compact(secp256k1_context_static, &sig, signatureSansPrefix, recid) != 0 else {
        preconditionFailure() // throw?
    }

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &pubkey, &sig, hash) != 0 else {
        return .none
    }

    var publen = comp ? compressedPublicKeySize : uncompressedPublicKeySize
    var pub = [UInt8](repeating: 0, count: publen)
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &pub, &publen, &pubkey, UInt32(comp ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    return Data(pub)
}
