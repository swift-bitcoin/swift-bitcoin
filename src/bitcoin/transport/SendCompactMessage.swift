import Foundation

/// BIP152
public struct SendCompactMessage: Equatable {

    init(highBandwidth: Bool = false, version: Int = 2) {
        self.highBandwidth = highBandwidth
        self.version = version
    }

    public let highBandwidth: Bool
    public let version: Int

    static let size = MemoryLayout<UInt8>.size + MemoryLayout<UInt64>.size
}

extension SendCompactMessage {

    var data: Data {
        var ret = Data(count: Self.size)
        let offset = ret.addBytes(UInt8(highBandwidth ? 1 : 0))
        ret.addBytes(UInt64(version), at: offset)
        return ret
    }

    public init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        var data = data
        let highBandwidth = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt8.self)
        }
        self.highBandwidth = highBandwidth == 1 ? true : false
        data = data.dropFirst(MemoryLayout<UInt8>.size)

        guard data.count >= MemoryLayout<UInt64>.size else { return nil }
        let version = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        self.version = Int(version)
    }
}
