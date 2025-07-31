import Foundation
import BitcoinCrypto
import BitcoinBase

struct BlockUndo: Equatable, Sendable {

    init(spentCoins: [UnspentOutput?]) {
        self.spentCoins = spentCoins
    }

    let spentCoins: [UnspentOutput?]
}

extension BlockUndo: CustomBinaryCodable {

    public init(from decoder: inout BinaryDecoder, encoding: Never?) throws {
        let length = Int(try decoder.decode() as UInt32)
        decoder.setLimit(length - MemoryLayout<UInt32>.size)
        spentCoins = try decoder.decode()
        decoder.resetLimit()
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
        encoder.encode(UInt32(dataSize))
        encoder.encode(spentCoins)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Encoding?) {
        counter.count(UInt32.self)
        counter.count(spentCoins)
    }
}
