import Foundation

extension InputSequence {

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let rawValue = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(Int(rawValue))
    }

    var data: Data {
        Data(value: rawValue)
    }

    static let size = MemoryLayout<UInt32>.size
}
