import Foundation
import LibSECP256k1
import ECCHelper // For `ecdsa_signature_parse_der_lax()`

public enum SignatureType: Equatable {
    case ecdsa, compact, recoverable(Bool?), schnorr
}

public struct Signature: Equatable, CustomStringConvertible {

    public init?(message: String, secretKey: SecretKey, type: SignatureType = .schnorr) {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        self.init(messageData: messageData, secretKey: secretKey, type: type)
    }

    public init(messageData: Data, secretKey: SecretKey, type: SignatureType, additionalEntropy: Data? = .none) {
        self.init(messageHash: getMessageHash(messageData: messageData, type: type), secretKey: secretKey, type: type, additionalEntropy: additionalEntropy)
    }

    public init(messageHash: Data, secretKey: SecretKey, type: SignatureType, additionalEntropy: Data? = .none) {
        precondition(messageHash.count == Self.hashLength)
        switch type {
        case .ecdsa:
            data = signECDSA(messageHash: messageHash, secretKey: secretKey)
        case .compact:
            data = signCompact(messageHash: messageHash, secretKey: secretKey)
        case .recoverable(let compressedPublicKeys):
            guard let compressedPublicKeys else {
                preconditionFailure()
            }
            data = signRecoverable(messageHash: messageHash, secretKey: secretKey, compressedPublicKeys: compressedPublicKeys)
            assert(data.count == Self.recoverableSignatureLength)
        case .schnorr:
            data = signSchnorr(messageHash: messageHash, secretKey: secretKey, additionalEntropy: additionalEntropy)
            assert(data.count == Self.schnorrSignatureLength)
        }
        self.type = type
    }

    public init?(_ hex: String, type: SignatureType = .schnorr) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data, type: type)
    }

    public init?(_ data: Data, type: SignatureType = .schnorr) {
        switch type {
        case .ecdsa:
            guard data.count >= Self.compactSignatureLength && data.count <= Self.ecdsaSignatureMaxLength else {
                return nil
            }
        case .compact:
            guard data.count == Self.compactSignatureLength else {
                return nil // This check covers high R because there would be 1 extra byte.
            }
            guard isLowS(compactSignatureData: data) else {
                return nil
            }
        case .recoverable(_):
            guard data.count == Self.recoverableSignatureLength else {
                return nil
            }
        case .schnorr:
            guard data.count == Self.schnorrSignatureLength else {
                return nil
            }
        }
        self.data = data
        self.type = type
    }

    public let data: Data
    public let type: SignatureType

    public var description: String {
        data.hex
    }

    public func verify(message: String, publicKey: PublicKey) -> Bool {
        guard let messageData = message.data(using: .utf8) else {
            return false
        }
        return verify(messageData: messageData, publicKey: publicKey)
    }

    public func verify(messageData: Data, publicKey: PublicKey) -> Bool {
        verify(messageHash: getMessageHash(messageData: messageData, type: type), publicKey: publicKey)
    }

    public func verify(messageHash: Data, publicKey: PublicKey) -> Bool {
        assert(messageHash.count == Self.hashLength)
        switch type {
        case .ecdsa:
            return verifyECDSA(signatureData: data, messageHash: messageHash, publicKey: publicKey)
        case .compact:
            return verifyCompact(signatureData: data, messageHash: messageHash, publicKey: publicKey)
        case .recoverable(_):
            return internalRecoverPublicKey(signatureData: data, messageHash: messageHash) != .none
        case .schnorr:
            return verifySchnorr(signatureData: data, messageHash: messageHash, publicKey: publicKey)
        }
    }

    public func recoverPublicKey(from messageData: Data) -> PublicKey? {
        guard case .recoverable(_) = type else {
            preconditionFailure()
        }
        guard let publicKeyData = internalRecoverPublicKey(signatureData: data, messageHash: getMessageHash(messageData: messageData, type: .recoverable(.none))) else {
            return .none
        }
        return PublicKey(publicKeyData)
    }

    /// Actually hash256
    static let hashLength = 32

    /// Non-canonical ECDSA signature serializations can grow up to 72 bytes without the sighash type 1-byte extension.
    public static let ecdsaSignatureMaxLength = 72

    /// Standard Schnorr signature extended with the sighash type byte.
    public static let extendedSchnorrSignatureLength = 65
    public static let schnorrSignatureLength = 64

    /// ECDSA Compact Signature (with non-recoverable public key)
    public static let compactSignatureLength = 64

    /// ECDSA Compact Signature with recoverable public key
    public static let recoverableSignatureLength = 65
}

// MARK: - Some helper functions

private func getMessageHash(messageData: Data, type: SignatureType) -> Data {
    let newMessageData: Data
    switch type {
    case .ecdsa, .compact, .schnorr:
        newMessageData = messageData
    case .recoverable(_):
        newMessageData = compactRecoverableMessage(messageData)
    }
    return hash256(newMessageData)
}

// MARK: - ECDSA Compact with Recoverable Public Key

/// Used for original Bitcoin message signing protocol.
private func compactRecoverableMessage(_ messageData: Data) -> Data {
    messageMagic.data(using: .utf8)! + messageData.varLenData
}

/// Produces an ECDSA signature that is compact and from which a public key can be recovered.
/// 
/// Requires global signing context to be initialized.
private func signRecoverable(messageHash: Data, secretKey: SecretKey, compressedPublicKeys: Bool) -> Data {
    // let hash = [UInt8](compactRecoverableMessageHash(message))
    let messageHashBytes = [UInt8](messageHash)
    let secretKeyBytes = [UInt8](secretKey.data)

    var rsig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_sign_recoverable(eccSigningContext, &rsig, messageHashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, nil) != 0 else {
        preconditionFailure()
    }

    var signatureBytes = [UInt8](repeating: 0, count: Signature.recoverableSignatureLength)
    var rec: Int32 = -1
    guard secp256k1_ecdsa_recoverable_signature_serialize_compact(eccSigningContext, &signatureBytes[1], &rec, &rsig) != 0 else {
        preconditionFailure()
    }

    precondition(rec >= 0 && rec < UInt8.max - 27 - (compressedPublicKeys ? 4 : 0))
    signatureBytes[0] = UInt8(27 + rec + (compressedPublicKeys ? 4 : 0))

    // Additional verification step to prevent using a potentially corrupted signature

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    var recoveredPubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &recoveredPubkey, &rsig, messageHashBytes) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ec_pubkey_cmp(secp256k1_context_static, &pubkey, &recoveredPubkey) == 0 else {
        preconditionFailure()
    }
    return Data(signatureBytes)
}

/// Recovers public key from signature which also verifies the signature as valid.
private func internalRecoverPublicKey(signatureData: Data, messageHash: Data) -> Data? {
    precondition(signatureData.count == Signature.recoverableSignatureLength) // throw?

    // TODO: Make it so that we respect the data index.
    assert(signatureData.startIndex == 0)

    let messageHashBytes = [UInt8](messageHash)

    let recid = Int32((signatureData[0] - 27) & 3)
    let comp = ((signatureData[0] - 27) & 4) != 0

    let signatureSansPrefix = [UInt8](signatureData[1...])
    var sig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_recoverable_signature_parse_compact(secp256k1_context_static, &sig, signatureSansPrefix, recid) != 0 else {
        preconditionFailure() // throw?
    }

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &pubkey, &sig, messageHashBytes) != 0 else {
        return .none
    }

    var publen = comp ? PublicKey.compressedLength : PublicKey.uncompressedLength
    var pub = [UInt8](repeating: 0, count: publen)
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &pub, &publen, &pubkey, UInt32(comp ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    return Data(pub)
}

// MARK: - ECDSA Compact

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
private func signCompact(messageHash: Data, secretKey: SecretKey) -> Data {
    let messageHash = [UInt8](messageHash)
    let secretKeyBytes = [UInt8](secretKey.data)

    precondition(messageHash.count == Signature.hashLength)
    precondition(secretKeyBytes.count == SecretKey.keyLength)

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

    var signatureBytes = [UInt8](repeating: 0, count: Signature.compactSignatureLength)
    guard secp256k1_ecdsa_signature_serialize_compact(secp256k1_context_static, &signatureBytes, &signature) != 0 else {
        preconditionFailure()
    }

    precondition(signatureBytes.count == Signature.compactSignatureLength)
    return Data(signatureBytes)
}

private func verifyCompact(signatureData: Data, messageHash: Data, publicKey: PublicKey) -> Bool {
    let signatureBytes = [UInt8](signatureData)
    let messageHash = [UInt8](messageHash)
    let publicKeyBytes = [UInt8](publicKey.data)

    precondition(signatureData.count == Signature.compactSignatureLength)
    precondition(messageHash.count == Signature.hashLength)

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

// MARK: - Schnorr

/// Requires global signing context to be initialized.
private func signSchnorr(messageHash: Data, secretKey: SecretKey, additionalEntropy: Data?) -> Data {
    precondition(messageHash.count == Signature.hashLength)

    let messageHashBytes = [UInt8](messageHash)
    let secretKeyBytes = [UInt8](secretKey.data)
    let auxBytes = if let additionalEntropy { [UInt8](additionalEntropy) } else { [UInt8]?.none }

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    // Do the signing.
    var sigOut = [UInt8](repeating: 0, count: 64)
    guard secp256k1_schnorrsig_sign32(eccSigningContext, &sigOut, messageHashBytes, &keypair, auxBytes) != 0 else {
        preconditionFailure()
    }

    // Additional verification step to prevent using a potentially corrupted signature.
    // This public key will be tweaked if a tweak was added to the keypair earlier.
    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &xonlyPubkey, nil, &keypair) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_schnorrsig_verify(secp256k1_context_static, sigOut, messageHashBytes, Signature.hashLength, &xonlyPubkey) != 0 else {
        preconditionFailure()
    }

    return Data(sigOut)
}

private func verifySchnorr(signatureData: Data, messageHash: Data, publicKey: PublicKey) -> Bool {

    precondition(signatureData.count == Signature.schnorrSignatureLength)
    precondition(messageHash.count == Signature.hashLength)
    // guard !publicKeyData.isEmpty else { return false }

    let signatureBytes = [UInt8](signatureData)
    let publicKeyBytes = [UInt8](publicKey.xOnlyData.x)
    let messageHashBytes = [UInt8](messageHash)

    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, publicKeyBytes) != 0 else {
        return false
    }
    return secp256k1_schnorrsig_verify(secp256k1_context_static, signatureBytes, messageHashBytes, messageHashBytes.count, &xonlyPubkey) != 0
}

// MARK: - ECDSA

/// Requires global signing context to be initialized.
private func signECDSA(messageHash: Data, secretKey: SecretKey, requireLowR: Bool = true) -> Data {

    precondition(messageHash.count == Signature.hashLength)

    let messageHashBytes = [UInt8](messageHash)
    let secretKeyBytes = [UInt8](secretKey.data)

    let testCase = UInt32(0)
    var extraEntropy = [UInt8](repeating: 0, count: 32)
    writeLE32(&extraEntropy, testCase)
    var signature = secp256k1_ecdsa_signature()
    var counter = UInt32(0)
    var success = secp256k1_ecdsa_sign(eccSigningContext, &signature, messageHashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, (requireLowR && testCase != 0) ? extraEntropy : nil) != 0
    // Grind for low R
    while (success && !isLowR(signature: &signature) && requireLowR) {
        counter += 1
        writeLE32(&extraEntropy, counter)
        success = secp256k1_ecdsa_sign(eccSigningContext,  &signature, messageHashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, extraEntropy) != 0
    }
    precondition(success)

    var signatureBytes = [UInt8](repeating: 0, count: Signature.ecdsaSignatureMaxLength)
    var signatureBytesCount = signatureBytes.count
    guard secp256k1_ecdsa_signature_serialize_der(secp256k1_context_static, &signatureBytes, &signatureBytesCount, &signature) != 0 else {
        preconditionFailure()
    }

    // Resize (shrink) if necessary
    let signatureShrunken = Data(signatureBytes[signatureBytes.startIndex ..< signatureBytes.startIndex.advanced(by: signatureBytesCount)])

    // Additional verification step to prevent using a potentially corrupted signature
    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ecdsa_verify(secp256k1_context_static, &signature, messageHashBytes, &pubkey) != 0 else {
        preconditionFailure()
    }

    return signatureShrunken
}

/// Verifies a signature using a public key.
private func verifyECDSA(signatureData: Data, messageHash: Data, publicKey: PublicKey) -> Bool {

    // TODO: Verify the assumption below
    // guard !publicKey.data.isEmpty else { return false }

    let signatureBytes = [UInt8](signatureData)
    let publicKeyBytes = [UInt8](publicKey.data)
    let messageHashBytes = [UInt8](messageHash)

    var signature = secp256k1_ecdsa_signature()
    guard ECCHelper.ecdsa_signature_parse_der_lax(&signature, signatureBytes, signatureBytes.count) != 0 else {
        preconditionFailure()
    }

    var signatureNormalized = secp256k1_ecdsa_signature()
    secp256k1_ecdsa_signature_normalize(secp256k1_context_static, &signatureNormalized, &signature)

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, publicKeyBytes, publicKeyBytes.count) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &signatureNormalized, messageHashBytes, &pubkey) != 0
}

// Check that the sig has a low R value and will be less than 71 bytes
private func isLowR(signature: inout secp256k1_ecdsa_signature) -> Bool {
    var compactSig = [UInt8](repeating: 0, count: 64)
    secp256k1_ecdsa_signature_serialize_compact(secp256k1_context_static, &compactSig, &signature);

    // In DER serialization, all values are interpreted as big-endian, signed integers. The highest bit in the integer indicates
    // its signed-ness; 0 is positive, 1 is negative. When the value is interpreted as a negative integer, it must be converted
    // to a positive value by prepending a 0x00 byte so that the highest bit is 0. We can avoid this prepending by ensuring that
    // our highest bit is always 0, and thus we must check that the first byte is less than 0x80.
    return compactSig[0] < 0x80
}

private func isLowS(compactSignatureData: Data) -> Bool {
    let signatureBytes = [UInt8](compactSignatureData)

    var signature = secp256k1_ecdsa_signature()
    guard secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, &signature, signatureBytes) != 0 else {
        preconditionFailure()
    }

    let normalizationOccurred = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, &signature)
    return normalizationOccurred == 0
}
