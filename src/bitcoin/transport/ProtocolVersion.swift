import Foundation

public enum ProtocolVersion: Int, Comparable, Sendable {

    case unsupported = 70015, latest = 70016, future = 70017

    init(_ value: Int) {
        self = if value == Self.latest.rawValue {
            .latest
        } else if value >= Self.future.rawValue {
            .future
        } else {
            .unsupported
        }
    }

    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension ProtocolVersion {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let value = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        self.init(Int(value))
    }

    var data: Data {
        Data(value: UInt32(rawValue))
    }

    static var size: Int { MemoryLayout<UInt32>.size }
}
