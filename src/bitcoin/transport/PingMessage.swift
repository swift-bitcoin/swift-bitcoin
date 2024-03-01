import Foundation

public struct PingMessage: Equatable {

    init() {
        self.nonce = .random(in: UInt64.min ... UInt64.max)
    }

    public let nonce: UInt64

    static let size = MemoryLayout<UInt64>.size
}

extension PingMessage {

    public init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
    }

    var data: Data {
        Data(value: nonce)
    }
}
