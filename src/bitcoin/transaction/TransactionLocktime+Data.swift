import Foundation

extension TransactionLocktime {

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        let value32 = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.init(Int(value32))
    }

    var data: Data {
        Data(value: rawValue)
    }

    static let size = MemoryLayout<UInt32>.size
}
