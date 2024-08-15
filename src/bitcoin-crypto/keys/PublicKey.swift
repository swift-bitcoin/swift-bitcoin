import Foundation

/// Serialization format.
public enum PublicKeyFormat {
    case uncompressed, compressed

    init?(length: Int) {
        switch length {
        case Self.uncompressed.length: self = .uncompressed
        case Self.compressed.length: self = .compressed
        default: return nil
        }
    }

    var length: Int {
        switch self {
        case .uncompressed: 65
        case .compressed: 33
        }
    }
}

public struct PublicKey: Equatable, CustomStringConvertible {

    public init(_ secretKey: SecretKey) {
        data = getPublicKey(secretKey: secretKey.data)
    }

    public init?(_ hex: String, format: PublicKeyFormat? = .compressed) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data, format: format)
    }

    public init?(_ data: Data, format: PublicKeyFormat? = .compressed) {
        let resolvedFormat: PublicKeyFormat
        if let format {
            guard data.count == format.length else {
                return nil
            }
            resolvedFormat = format
        } else {
            // Auto-detect format
            guard let inferredFormat = PublicKeyFormat(length: data.count) else {
                return nil
            }
            resolvedFormat = inferredFormat
        }
        guard checkPublicKey(data) else {
            return nil
        }
        switch resolvedFormat {
        case .uncompressed:
            self.data = publicKeyToCompressed(data)
        case .compressed:
            self.data = data
        }
    }

    public let data: Data

    public var description: String {
        data.hex
    }

    public func description(_ format: PublicKeyFormat = .compressed) -> String {
        data(format).hex
    }

    public func data(_ format: PublicKeyFormat = .compressed) -> Data {
        switch format {
        case .uncompressed:
            publicKeyToUncompressed(data)
        case .compressed:
            data
        }
    }

    public var xOnlyData: Data {
        publicKeyToXOnly(data)
    }

    public func matches(_ secretKey: SecretKey) -> Bool {
        self == PublicKey(secretKey)
    }

    public func verify(_ signature: Signature, for message: String) -> Bool {
        signature.verify(for: message, using: self)
    }
}
