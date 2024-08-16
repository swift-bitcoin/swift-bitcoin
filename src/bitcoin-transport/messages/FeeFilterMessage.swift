import Foundation
import BitcoinBase

/// BIP133 - https://github.com/bitcoin/bips/blob/master/bip-0133.mediawiki
public struct FeeFilterMessage: Equatable {

    init(feeRate: BitcoinAmount) {
        self.feeRate = feeRate
    }

    /// Satoshis per virtual byte.
    public let feeRate: BitcoinAmount

    static let size = MemoryLayout<UInt64>.size
}

extension FeeFilterMessage {

    var data: Data {
        Data(value: UInt64(feeRate))
    }

    public init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let feeRateRaw = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        feeRate = BitcoinAmount(feeRateRaw)
    }
}
