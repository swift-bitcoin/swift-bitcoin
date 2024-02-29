import Foundation

struct ProtocolServices: OptionSet {
    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    init?(_ data: Data) {
        guard data.count >= MemoryLayout<RawValue>.size else { return nil }
        let rawValue = data.withUnsafeBytes {
            $0.loadUnaligned(as: RawValue.self)
        }
        self.init(rawValue: rawValue)
    }

    let rawValue: UInt64

    static let network = Self(rawValue: 1 << 0)
    static let witness = Self(rawValue: 1 << 3)

    static let empty: Self = []
    static let all: Self = [.network, .witness]

    static var size: Int { MemoryLayout<RawValue>.size }
}
