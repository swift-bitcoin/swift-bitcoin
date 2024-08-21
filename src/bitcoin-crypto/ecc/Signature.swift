import Foundation
import LibSECP256k1

public enum SignatureType: Equatable {
    case compact, recoverable(Bool?), schnorr
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
        case .compact:
            guard data.count == Self.compactSignatureLength else {
                return nil // This check covers high R because there would be 1 extra byte.
            }
            guard isLowS(compactSignature: data) else {
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
    case .compact, .schnorr:
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

    var sig = [UInt8](repeating: 0, count: recoverableSignatureSize)
    var rec: Int32 = -1
    guard secp256k1_ecdsa_recoverable_signature_serialize_compact(eccSigningContext, &sig[1], &rec, &rsig) != 0 else {
        preconditionFailure()
    }

    precondition(rec >= 0 && rec < UInt8.max - 27 - (compressedPublicKeys ? 4 : 0))
    sig[0] = UInt8(27 + rec + (compressedPublicKeys ? 4 : 0))

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
    return Data(sig)
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

    var publen = comp ? compressedPublicKeySize : uncompressedPublicKeySize
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

private func verifyCompact(signatureData: Data, messageHash: Data, publicKey: PublicKey) -> Bool {
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
