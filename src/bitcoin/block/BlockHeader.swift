import Foundation

/// A block's header.
public struct BlockHeader: Equatable {

    public init(version: Int = 2, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0) {
        self.version = version
        self.previous = previous
        self.merkleRoot = merkleRoot

        // Reset date's nanoseconds
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard let time = calendar.date(bySetting: .nanosecond, value: 0, of: time) else { preconditionFailure() }
        self.time = time

        self.target = target
        self.nonce = nonce
    }
    

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        var data = data
        version = Int(data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        data = data.dropFirst(MemoryLayout<Int32>.size)
        previous = Data(data[..<data.startIndex.advanced(by: 32)].reversed())
        data = data.dropFirst(previous.count)
        merkleRoot = Data(data[..<data.startIndex.advanced(by: 32)].reversed())
        data = data.dropFirst(merkleRoot.count)
        let seconds = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        time = Date(timeIntervalSince1970: TimeInterval(seconds))
        data = data.dropFirst(MemoryLayout.size(ofValue: seconds))
        target = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)
        nonce = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)
    }

    // MARK: - Instance Properties

    public let version: Int
    public let previous: Data
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data(capacity: Self.size)
        ret.addBytes(of: Int32(version))
        ret.append(contentsOf: previous.reversed())
        ret.append(contentsOf: merkleRoot.reversed())
        ret.addBytes(of: UInt32(time.timeIntervalSince1970))
        ret.addBytes(of: UInt32(target))
        ret.addBytes(of: UInt32(nonce))
        return ret
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    /// Size of data in bytes.
    static let size = 80

    // MARK: - Type Methods

    // No type methods yet.
}
