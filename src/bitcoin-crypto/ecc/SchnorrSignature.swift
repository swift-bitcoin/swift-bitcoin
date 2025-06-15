import Foundation
import LibSECP256k1

/// Elliptic curve SECP256K1 signature supporting Schnorr algorithm.
public struct SchnorrSignature: Equatable, Sendable, CustomStringConvertible {

    public init?(message: String, secretKey: SecretKey) {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        self.init(messageData: messageData, secretKey: secretKey)
    }

    public init(messageData: Data, secretKey: SecretKey, additionalEntropy: Data? = nil) {
        self.init(hash: getMessageHash(messageData: messageData), secretKey: secretKey, additionalEntropy: additionalEntropy)
    }

    public init(hash: Data, secretKey: SecretKey, additionalEntropy: Data? = nil) {
        precondition(hash.count == Self.hashLength)
        data = signSchnorr(hash: hash, secretKey: secretKey, additionalEntropy: additionalEntropy)
        assert(data.count == Self.schnorrSignatureLength)
    }

    public init?(_ hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data)
    }

    public init?(_ data: Data) {
        guard data.count == Self.schnorrSignatureLength else {
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
        return verifySchnorr(sigData: data, hash: hash, pubkey: pubkey)
    }

    /// Actually hash256
    static let hashLength = Hash256.Digest.byteCount

    /// Standard Schnorr signature extended with the sighash type byte.
    public static let schnorrSignatureLength = 64
}

private func getMessageHash(messageData: Data) -> Data {
    Data(Hash256.hash(data: messageData))
}

/// Requires global signing context to be initialized.
private func signSchnorr(hash: Data, secretKey: SecretKey, additionalEntropy: Data?) -> Data {
    precondition(hash.count == ECDSASignature.hashLength)

    let hashBytes = [UInt8](hash)
    let secretKeyBytes = [UInt8](secretKey.data)
    let auxBytes = if let additionalEntropy { [UInt8](additionalEntropy) } else { [UInt8]?.none }

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    // Do the signing.
    var sigOut = [UInt8](repeating: 0, count: 64)
    guard secp256k1_schnorrsig_sign32(eccSigningContext, &sigOut, hashBytes, &keypair, auxBytes) != 0 else {
        preconditionFailure()
    }

    // Additional verification step to prevent using a potentially corrupted signature.
    // This public key will be tweaked if a tweak was added to the keypair earlier.
    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &xonlyPubkey, nil, &keypair) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_schnorrsig_verify(secp256k1_context_static, sigOut, hashBytes, ECDSASignature.hashLength, &xonlyPubkey) != 0 else {
        preconditionFailure()
    }

    return Data(sigOut)
}

private func verifySchnorr(sigData: Data, hash: Data, pubkey: PublicKey) -> Bool {

    precondition(sigData.count == SchnorrSignature.schnorrSignatureLength)
    precondition(hash.count == ECDSASignature.hashLength)
    // guard !pubkeyData.isEmpty else { return false }

    let sigBytes = [UInt8](sigData)
    let pubkeyBytes = [UInt8](pubkey.xOnlyData)
    let hashBytes = [UInt8](hash)

    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, pubkeyBytes) != 0 else {
        return false
    }
    return secp256k1_schnorrsig_verify(secp256k1_context_static, sigBytes, hashBytes, hashBytes.count, &xonlyPubkey) != 0
}
