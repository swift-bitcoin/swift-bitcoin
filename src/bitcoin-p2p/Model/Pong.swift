import Foundation

struct Pong: Equatable {

    init(nonce: UInt64) {
        self.nonce = nonce
    }

    let nonce: UInt64

    static let size = MemoryLayout<UInt64>.size
}

extension Pong {

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
