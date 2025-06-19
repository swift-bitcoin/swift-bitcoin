import Foundation
import LibSECP256k1

/// Elliptic curve SECP256K1 signature supporting ECDSA algorithms.
public struct RecoverableSignature: Equatable, Sendable, CustomStringConvertible {

    public init?(message: String, secretKey: SecretKey, recoverCompressedKeys: Bool = true) {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        self.init(messageData: messageData, secretKey: secretKey, recoverCompressedKeys: recoverCompressedKeys)
    }

    public init(messageData: Data, secretKey: SecretKey, additionalEntropy: Data? = nil, recoverCompressedKeys: Bool = true) {
        self.init(hash: getMessageHash(messageData: messageData), secretKey: secretKey, recoverCompressedKeys: recoverCompressedKeys)
    }

    public init(hash: Data, secretKey: SecretKey, additionalEntropy: Data? = nil, recoverCompressedKeys: Bool = true) {
        precondition(hash.count == Self.hashLength)
        data = signRecoverable(hash: hash, secretKey: secretKey, compressedPubkeys: recoverCompressedKeys)
        assert(data.count == Self.recoverableSignatureLength)
    }

    public init?(_ hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data)
    }

    public init?(_ data: Data) {
        guard data.count == Self.recoverableSignatureLength else {
            return nil
        }
        self.data = data
    }

    public let data: Data

    public var description: String {
        data.hex
    }

    public var base64: String {
        data.base64EncodedString()
    }

    public func verify(message: String, pubkey: PublicKey) -> Bool {
        guard let messageData = message.data(using: .utf8) else {
            return false
        }
        return verify(messageData: messageData, pubkey: pubkey)
    }

    public func verify(messageData: Data, pubkey: PublicKey) -> Bool {
        verify(hash: getMessageHash(messageData: messageData), pubkey: pubkey)
    }

    public func verify(hash: Data, pubkey: PublicKey) -> Bool {
        assert(hash.count == Self.hashLength)
        return internalRecoverPubkey(sigData: data, hash: hash) != nil
    }

    public func recoverPubkey(from message: String) -> PublicKey? {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        return recoverPubkey(messageData: messageData)
    }

    public func recoverPubkey(messageData: Data) -> PublicKey? {
        guard let pubkeyData = internalRecoverPubkey(sigData: data, hash: getMessageHash(messageData: messageData)) else {
            return nil
        }
        return PublicKey(pubkeyData)
    }

    /// Actually hash256
    static let hashLength = Hash256.Digest.byteCount

    /// ECDSA Compact Signature with recoverable public key
    public static let recoverableSignatureLength = 65
}

// MARK: - Some helper functions

private func getMessageHash(messageData: Data) -> Data {
    Data(Hash256.hash(data: compactRecoverableMessage(messageData)))
}

/// Text used to signify that a signed message follows and to prevent inadvertently signing a transaction.
///
/// Used by `compactRecoverableMessage()`.
private let messageMagic = "\u{18}Bitcoin Signed Message:\n"

/// Used for original Bitcoin message signing protocol.
private func compactRecoverableMessage(_ messageData: Data) -> Data {
    messageMagic.data(using: .utf8)! + VarInt(messageData.count).data + messageData
}

/// Produces an ECDSA signature that is compact and from which a public key can be recovered.
///
/// Requires global signing context to be initialized.
private func signRecoverable(hash: Data, secretKey: SecretKey, compressedPubkeys: Bool) -> Data {
    // let hash = [UInt8](compactRecoverableMessageHash(message))
    let hashBytes = [UInt8](hash)
    let secretKeyBytes = [UInt8](secretKey.data)

    var rsig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_sign_recoverable(eccSigningContext, &rsig, hashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, nil) != 0 else {
        preconditionFailure()
    }

    var sigBytes = [UInt8](repeating: 0, count: RecoverableSignature.recoverableSignatureLength)
    var rec: Int32 = -1
    guard secp256k1_ecdsa_recoverable_signature_serialize_compact(eccSigningContext, &sigBytes[1], &rec, &rsig) != 0 else {
        preconditionFailure()
    }

    precondition(rec >= 0 && rec < UInt8.max - 27 - (compressedPubkeys ? 4 : 0))
    sigBytes[0] = UInt8(27 + rec + (compressedPubkeys ? 4 : 0))

    // Additional verification step to prevent using a potentially corrupted signature

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    var recoveredPubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &recoveredPubkey, &rsig, hashBytes) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ec_pubkey_cmp(secp256k1_context_static, &pubkey, &recoveredPubkey) == 0 else {
        preconditionFailure()
    }
    return Data(sigBytes)
}

/// Recovers public key from signature which also verifies the signature as valid.
private func internalRecoverPubkey(sigData: Data, hash: Data) -> Data? {
    precondition(sigData.count == RecoverableSignature.recoverableSignatureLength) // throw?

    // TODO: Make it so that we respect the data index.
    assert(sigData.startIndex == 0)

    let hashBytes = [UInt8](hash)

    let recid = Int32((sigData[0] - 27) & 3)
    let comp = ((sigData[0] - 27) & 4) != 0

    let sigSansPrefix = [UInt8](sigData.dropFirst())
    var sig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_recoverable_signature_parse_compact(secp256k1_context_static, &sig, sigSansPrefix, recid) != 0 else {
        preconditionFailure() // throw?
    }

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &pubkey, &sig, hashBytes) != 0 else {
        return nil
    }

    var publen = comp ? PublicKey.compressedLength : PublicKey.uncompressedLength
    var pub = [UInt8](repeating: 0, count: publen)
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &pub, &publen, &pubkey, UInt32(comp ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    return Data(pub)
}
