import Foundation

struct Ping: Equatable {

    public init() {
        self.nonce = .random(in: UInt64.min ... UInt64.max)
    }

    public let nonce: UInt64

    static let size = MemoryLayout<UInt64>.size
}

extension Ping {

    var data: Data {
        Data(value: nonce)
    }

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
    }
}
