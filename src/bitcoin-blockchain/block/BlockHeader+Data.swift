import Foundation

extension BlockHeader {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        var data = data
        version = Int(data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        data = data.dropFirst(MemoryLayout<Int32>.size)
        previous = Data(data.prefix(32).reversed())
        data = data.dropFirst(previous.count)
        merkleRoot = Data(data.prefix(32).reversed())
        data = data.dropFirst(merkleRoot.count)
        let seconds = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        time = Date(timeIntervalSince1970: TimeInterval(seconds))
        data = data.dropFirst(MemoryLayout.size(ofValue: seconds))
        target = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)
        nonce = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)
    }

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data(count: Self.size)
        var offset = ret.addBytes(Int32(version))
        offset = ret.addData(previous.reversed(), at: offset)
        offset = ret.addData(merkleRoot.reversed(), at: offset)
        offset = ret.addBytes(UInt32(time.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(UInt32(target), at: offset)
        offset = ret.addBytes(UInt32(nonce), at: offset)
        return ret
    }

    // MARK: - Type Properties

    /// Size of data in bytes.
    public static let size = 80
}
