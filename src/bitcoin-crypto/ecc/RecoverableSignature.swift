import Foundation
import CSECP256K1

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

    var rsig = CollectionOfOne(ECDSARecoverableSignature())
    var rsigSpan = rsig.mutableSpan
    guard eccSigningContext.ecdsaSignRecoverable(sig: &rsigSpan, msghash32: hash.span, seckey: secretKey.data.span, noncefp: .rfc6979) != 0 else {
        preconditionFailure()
    }

    var sigBytes = [UInt8](repeating: 0, count: RecoverableSignature.recoverableSignatureLength - 1)
    var sigBytesSpan = sigBytes.mutableSpan
    var rec = CollectionOfOne(Int32(-1))
    var recSpan = rec.mutableSpan
    guard eccSigningContext.ecdsaRecoverableSignatureSerializeCompact(output64: &sigBytesSpan, recid: &recSpan, sig: rsig.span) != 0 else {
        preconditionFailure()
    }

    let recID = rec[0]
    precondition(recID >= 0 && recID < UInt8.max - 27 - (compressedPubkeys ? 4 : 0))
    let firstByte = UInt8(27 + recID + (compressedPubkeys ? 4 : 0))

    // Additional verification step to prevent using a potentially corrupted signature

    var pubkey = CollectionOfOne(Pubkey())
    var pubkeySpan = pubkey.mutableSpan
    guard eccSigningContext.ecPubkeyCreate(&pubkeySpan, secretKey: secretKey.data.span) != 0 else {
        preconditionFailure()
    }

    var recoveredPubkey = CollectionOfOne(Pubkey())
    var recoveredPubkeySpan = recoveredPubkey.mutableSpan
    guard SECP256K1Context.shared.ecdsaRecover(pubkey: &recoveredPubkeySpan, sig: rsig.span, msghash32: hash.span) != 0 else {
        preconditionFailure()
    }

    guard SECP256K1Context.shared.ecPubkeyCmp(pubkey1: pubkey.span, pubkey2: recoveredPubkey.span) == 0 else {
        preconditionFailure()
    }
    return Data([firstByte] + sigBytes)
}

/// Recovers public key from signature which also verifies the signature as valid.
private func internalRecoverPubkey(sigData: Data, hash: Data) -> Data? {
    precondition(sigData.count == RecoverableSignature.recoverableSignatureLength) // throw?

    // TODO: Make it so that we respect the data index.
    assert(sigData.startIndex == 0)

    let recid = Int32((sigData[0] - 27) & 3)
    let comp = ((sigData[0] - 27) & 4) != 0

    let sigSansPrefix = [UInt8](sigData.dropFirst())
    var sig = CollectionOfOne(ECDSARecoverableSignature())
    var sigSpan = sig.mutableSpan
    guard SECP256K1Context.shared.ecdsaRecoverableSignatureParseCompact(sig: &sigSpan, input64: sigSansPrefix.span, recid: recid) != 0 else {
        preconditionFailure() // throw?
    }

    var pubkey = CollectionOfOne(Pubkey())
    var pubkeySpan = pubkey.mutableSpan
    guard SECP256K1Context.shared.ecdsaRecover(pubkey: &pubkeySpan, sig: sig.span, msghash32: hash.span) != 0 else {
        return nil
    }

    var pub = [UInt8](repeating: 0, count: PublicKey.uncompressedLength)
    var length = CollectionOfOne(pub.count)
    var pubSpan = pub.mutableSpan
    var lengthSpan = length.mutableSpan

    guard SECP256K1Context.shared.ecPubkeySerialize(output: &pubSpan, outputlen: &lengthSpan, pubkey: pubkey.span, flags: UInt32(comp ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    precondition(length[0] == (comp ? PublicKey.compressedLength : PublicKey.uncompressedLength))
    return Data(pub.prefix(length[0]))
}

private extension SECP256K1Context {
    func ecdsaSignRecoverable(sig: inout MutableSpan<ECDSARecoverableSignature>, msghash32: Span<UInt8>, seckey: Span<UInt8>, noncefp: NonceFunction?) -> Int32 {
        unsafe self.ecdsaSignRecoverable(sig: &sig, msghash32: msghash32, seckey: seckey, noncefp: noncefp, ndata: nil)
    }
}
