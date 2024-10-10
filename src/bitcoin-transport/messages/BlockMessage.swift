import Foundation
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain

public struct BlockMessage: Equatable, Sendable {

    // MARK: - Initializers

    public init(version: Int = 2, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0, transactions: [BitcoinTransaction] = []) {
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
        self.transactions = transactions
    }

    public init(header: BlockHeader, transactions: [BitcoinTransaction]) {
        version = header.version
        previous = header.previous
        merkleRoot = header.merkleRoot
        time = header.time
        target = header.target
        nonce = header.nonce
        self.transactions = transactions
    }

    // MARK: - Instance Properties

    public let version: Int
    public let previous: Data
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int
    public let transactions: [BitcoinTransaction]

    // MARK: - Computed Properties

    var header: BlockHeader {
        .init(version: version, previous: previous, merkleRoot: merkleRoot, time: time, target: target, nonce: nonce)
    }
    public var hash: Data {
        Data(Hash256.hash(data: data))
    }

    public var hashHex: String {
        hash.hex
    }

    public var identifier: Data {
        Data(hash.reversed())
    }

    public var identifierHex: String {
        identifier.hex
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    // No type methods yet.
}

extension BlockMessage {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        guard data.count >= Self.baseSize else {
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

        guard let txCount = data.varInt else {
            return nil
        }
        data = data.dropFirst(txCount.varIntSize)

        var transactions = [BitcoinTransaction]()
        for _ in 0 ..< txCount {
            guard let tx = BitcoinTransaction(data) else {
                return nil
            }
            transactions.append(tx)
            data = data.dropFirst(tx.size)
        }
        self.transactions = transactions
    }

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addBytes(Int32(version))
        offset = ret.addData(previous.reversed(), at: offset)
        offset = ret.addData(merkleRoot.reversed(), at: offset)
        offset = ret.addBytes(UInt32(time.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(UInt32(target), at: offset)
        offset = ret.addBytes(UInt32(nonce), at: offset)
        offset = ret.addData(Data(varInt: UInt64(transactions.count)), at: offset)
        offset = ret.addData(transactions.reduce(Data()) { $0 + $1.data }, at: offset)
        return ret
    }

    /// Size of data in bytes.
    public var size: Int {
        Self.baseSize + UInt64(transactions.count).varIntSize + transactions.reduce(0) { $0 + $1.size }
    }

    // MARK: - Type Properties

    public static let baseSize = 80
}
