import Foundation

public enum SignatureType {
    case ecdsa, schnorr
}

public struct Signature: Equatable, CustomStringConvertible {

    public init?(for message: String, using secretKey: SecretKey, type: SignatureType = .schnorr) {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        let messageHash = hash256(messageData)
        assert(messageHash.count == Self.hashLength)
        switch type {
        case .ecdsa:
            data = signCompact(messageHash: messageHash, secretKey: secretKey)
        case .schnorr:
            data = signSchnorr(msg: messageHash, secretKey: secretKey, aux: .none)
            assert(data.count == Self.signatureLength)
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
        guard data.count == Self.signatureLength else {
            return nil // This check covers high R because there would be 1 extra byte.
        }
        if type == .ecdsa {
            guard isLowS(compactSignature: data) else {
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

    public func verify(for message: String, using publicKey: PublicKey) -> Bool {
        guard let messageData = message.data(using: .utf8) else {
            return false
        }
        let messageHash = hash256(messageData)
        assert(messageHash.count == Self.hashLength)
        switch type {
        case .ecdsa:
            return verifyCompact(signature: data, messageHash: messageHash, publicKey: publicKey)
        case .schnorr:
            return verifySchnorr(sig: data, msg: messageHash, publicKey: publicKey)
        }
    }

    static let hashLength = 32
    static let signatureLength = 64 // Compact (with non-recoverable public key) and Schnorr
}
