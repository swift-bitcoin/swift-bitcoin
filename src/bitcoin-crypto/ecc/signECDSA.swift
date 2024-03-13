import Foundation
import LibSECP256k1

/// Requires global signing context to be initialized.
public func signECDSA(message messageData: Data, secretKey secretKeyData: Data, grind: Bool = true) -> Data {

    precondition(secretKeyData.count == secretKeySize)
    precondition(messageData.count == messageHashSize)

    let msg = [UInt8](messageData)
    let secretKey = [UInt8](secretKeyData)

    let testCase = UInt32(0)
    var extraEntropy = [UInt8](repeating: 0, count: 32)
    writeLE32(&extraEntropy, testCase)
    var sig = secp256k1_ecdsa_signature()
    var counter = UInt32(0)
    var success = secp256k1_ecdsa_sign(eccSigningContext, &sig, msg, secretKey, secp256k1_nonce_function_rfc6979, (grind && testCase != 0) ? extraEntropy : nil) != 0
    // Grind for low R
    while (success && !sigHasLowR(&sig) && grind) {
        counter += 1
        writeLE32(&extraEntropy, counter)
        success = secp256k1_ecdsa_sign(eccSigningContext,  &sig, msg, secretKey, secp256k1_nonce_function_rfc6979, extraEntropy) != 0
    }
    precondition(success)

    var sigBytes = [UInt8](repeating: 0, count: signatureSize)
    var sigBytesCount = sigBytes.count
    guard secp256k1_ecdsa_signature_serialize_der(secp256k1_context_static, &sigBytes, &sigBytesCount, &sig) != 0 else {
        preconditionFailure()
    }

    // Resize (shrink) if necessary
    let signature = Data(sigBytes[sigBytes.startIndex ..< sigBytes.startIndex.advanced(by: sigBytesCount)])

    // Additional verification step to prevent using a potentially corrupted signature
    var pk = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pk, secretKey) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ecdsa_verify(secp256k1_context_static, &sig, msg, &pk) != 0 else {
        preconditionFailure()
    }

    return signature
}

// Check that the sig has a low R value and will be less than 71 bytes
private func sigHasLowR(_ sig: inout secp256k1_ecdsa_signature) -> Bool {
    var compactSig = [UInt8](repeating: 0, count: 64)
    secp256k1_ecdsa_signature_serialize_compact(secp256k1_context_static, &compactSig, &sig);

    // In DER serialization, all values are interpreted as big-endian, signed integers. The highest bit in the integer indicates
    // its signed-ness; 0 is positive, 1 is negative. When the value is interpreted as a negative integer, it must be converted
    // to a positive value by prepending a 0x00 byte so that the highest bit is 0. We can avoid this prepending by ensuring that
    // our highest bit is always 0, and thus we must check that the first byte is less than 0x80.
    return compactSig[0] < 0x80
}

private func writeLE32(_ destination: inout [UInt8], _ x: UInt32) {
    precondition(destination.count >= 4)
    var v = x.littleEndian // On LE platforms this line does nothing
    assert(v == x) // Remove once we are ready to try BE platform
    withUnsafeBytes(of: &v) {
        destination.replaceSubrange(0..<4, with: $0)
    }
}
