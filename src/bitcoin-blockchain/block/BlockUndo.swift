import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase

struct BlockUndo: Equatable, Sendable {

    init(spentCoins: [UnspentOutput?]) {
        self.spentCoins = spentCoins
    }

    let spentCoins: [UnspentOutput?]
}

extension BlockUndo: BinaryCodable {

    init(parsing input: inout ParserSpan, format: Never?) throws {
        // TODO: - Block undo probably need the netowrk magic bytes (passed in custom binary format) to match block storage.
        // let magic = Int(try UInt32(parsingLittleEndian: &input))
        // guard magic == magicBytes else {
        //     throw BinaryDecodingError.invalidMessageStart
        // }

        let length = Int(try UInt32(parsingLittleEndian: &input))
        var trimmedInput = try input.sliceSpan(byteCount: length)
        spentCoins = try .init(parsing: &trimmedInput)
        try input.seek(toAbsoluteOffset: trimmedInput.endPosition)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
        counter.count(spentCoins)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt32(binarySize - MemoryLayout<UInt32>.size), as: UInt32.self, .littleEndian)
        try spentCoins.encode(into: &out)
    }
}
