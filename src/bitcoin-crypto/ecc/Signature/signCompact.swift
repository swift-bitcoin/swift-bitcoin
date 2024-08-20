import Foundation
import LibSECP256k1

/// Creates an ECDSA signature with low R value and returns its 64-byte compact (public key non-recoverable) serialization.
///
/// The generated signature will be verified before this function can return.
///
/// Note: This function requires global signing context to be initialized.
///
/// - Parameters:
///   - messageHash: 32-byte message hash data.
///   - secretKey: 32-byte secret key data.
/// - Returns: 64-byte compact signature data.
///
public func signCompact(messageHash: Data, secretKey: SecretKey) -> Data {
    let messageHash = [UInt8](messageHash)
    let secretKeyBytes = [UInt8](secretKey.data)

    precondition(messageHash.count == messageHashSize)
    precondition(secretKeyBytes.count == secretKeySize)

    let testCase = UInt32(0)
    var extraEntropy = [UInt8](repeating: 0, count: 32)
    writeLE32(&extraEntropy, testCase)
    var signature = secp256k1_ecdsa_signature()
    var counter = UInt32(0)
    var success = secp256k1_ecdsa_sign(eccSigningContext, &signature, messageHash, secretKeyBytes, secp256k1_nonce_function_rfc6979, testCase != 0 ? extraEntropy : nil) != 0
    // Grind for low R
    while success && !isLowR(signature: &signature) {
        counter += 1
        writeLE32(&extraEntropy, counter)
        success = secp256k1_ecdsa_sign(eccSigningContext,  &signature, messageHash, secretKeyBytes, secp256k1_nonce_function_rfc6979, extraEntropy) != 0
    }
    precondition(success)

    // Additional verification step to prevent using a potentially corrupted signature
    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }
    guard secp256k1_ecdsa_verify(secp256k1_context_static, &signature, messageHash, &pubkey) != 0 else {
        preconditionFailure()
    }

    var signatureBytes = [UInt8](repeating: 0, count: compactSignatureSize)
    guard secp256k1_ecdsa_signature_serialize_compact(secp256k1_context_static, &signatureBytes, &signature) != 0 else {
        preconditionFailure()
    }

    precondition(signatureBytes.count == compactSignatureSize)
    return Data(signatureBytes)
}
