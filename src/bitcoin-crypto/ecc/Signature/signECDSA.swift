import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func signECDSA(message messageData: Data, secretKey: SecretKey, grind: Bool = true) -> Data {

    precondition(messageData.count == messageHashSize)

    let msg = [UInt8](messageData)
    let secretKeyBytes = [UInt8](secretKey.data)

    let testCase = UInt32(0)
    var extraEntropy = [UInt8](repeating: 0, count: 32)
    writeLE32(&extraEntropy, testCase)
    var sig = secp256k1_ecdsa_signature()
    var counter = UInt32(0)
    var success = secp256k1_ecdsa_sign(eccSigningContext, &sig, msg, secretKeyBytes, secp256k1_nonce_function_rfc6979, (grind && testCase != 0) ? extraEntropy : nil) != 0
    // Grind for low R
    while (success && !isLowR(signature: &sig) && grind) {
        counter += 1
        writeLE32(&extraEntropy, counter)
        success = secp256k1_ecdsa_sign(eccSigningContext,  &sig, msg, secretKeyBytes, secp256k1_nonce_function_rfc6979, extraEntropy) != 0
    }
    precondition(success)

    var sigBytes = [UInt8](repeating: 0, count: ecdsaSignatureMaxSize)
    var sigBytesCount = sigBytes.count
    guard secp256k1_ecdsa_signature_serialize_der(secp256k1_context_static, &sigBytes, &sigBytesCount, &sig) != 0 else {
        preconditionFailure()
    }

    // Resize (shrink) if necessary
    let signature = Data(sigBytes[sigBytes.startIndex ..< sigBytes.startIndex.advanced(by: sigBytesCount)])

    // Additional verification step to prevent using a potentially corrupted signature
    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ecdsa_verify(secp256k1_context_static, &sig, msg, &pubkey) != 0 else {
        preconditionFailure()
    }

    return signature
}
