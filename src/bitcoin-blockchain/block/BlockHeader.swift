import Foundation
import BitcoinCrypto

/// A block's header.
public struct BlockHeader: Equatable, Sendable {

    // MARK: - Initializers

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

    // MARK: - Instance Properties

    public let version: Int
    public let previous: Data
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int

    // MARK: - Computed Properties

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
