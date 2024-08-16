import Foundation

public struct ProtocolServices: OptionSet, Sendable {
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    public let rawValue: UInt64

    public static let network = Self(rawValue: 1 << 0)
    public static let witness = Self(rawValue: 1 << 3)

    public static let empty: Self = []
    public static let all: Self = [.network, .witness]
}

extension ProtocolServices {

    init?(_ data: Data) {
        guard data.count >= MemoryLayout<RawValue>.size else { return nil }
        let rawValue = data.withUnsafeBytes {
            $0.loadUnaligned(as: RawValue.self)
        }
        self.init(rawValue: rawValue)
    }

    static var size: Int { MemoryLayout<RawValue>.size }
}
