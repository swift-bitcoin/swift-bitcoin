import Foundation

public struct SecretKey: Equatable, CustomStringConvertible {

    public init() {
        data = createSecretKey()
    }

    public init?(_ data: Data) {
        guard data.count == Self.keyLength else {
            return nil
        }
        guard checkSecretKey(data) else {
            return nil
        }
        self.data = data
    }

    public init?(_ hex: String) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data)
    }

    public let data: Data

    public var description: String {
        data.hex
    }

    public var publicKey: PublicKey {
        .init(self)
    }

    public func sign(_ message: String, signatureType: SignatureType = .schnorr) -> Signature? {
        .init(for: message, using: self, type: signatureType)
    }

    static let keyLength = 32
}
