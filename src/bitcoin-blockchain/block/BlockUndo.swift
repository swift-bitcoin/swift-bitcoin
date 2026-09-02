import Foundation
import BitcoinCrypto
import BitcoinBase

struct BlockUndo: Equatable, Sendable {

    init(spentCoins: [UnspentOutput?]) {
        self.spentCoins = spentCoins
    }

    let spentCoins: [UnspentOutput?]
}

extension BlockUndo: BinaryCodable {

    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let length = Int(try decoder.decode() as UInt32)
        decoder.setLimit(length - MemoryLayout<UInt32>.size)
        spentCoins = try .init(from: &decoder, format: nil)
        decoder.resetLimit()
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        counter.count(UInt32.self)
        counter.count(spentCoins)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt32(binarySize), as: UInt32.self, .littleEndian)
        try spentCoins.encode(into: &out)
    }

    /*
    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(UInt32(binarySize))
        encoder.encode(spentCoins)
    }
    */
}
