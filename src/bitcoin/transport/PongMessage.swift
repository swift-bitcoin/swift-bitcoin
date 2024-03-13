import Foundation

public struct PongMessage: Equatable, Sendable {

    init(nonce: UInt64) {
        self.nonce = nonce
    }

    public let nonce: UInt64

    static let size = MemoryLayout<UInt64>.size
}

extension PongMessage {

    var data: Data {
        Data(value: nonce)
    }

    public init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
    }
}
