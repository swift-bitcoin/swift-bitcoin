import Foundation
import Testing
import BinaryParsing
@testable import BitcoinCrypto

@Test(arguments: [
    (0, 1),
    (Int(UInt8.max) - 3, 1),
    (Int(UInt8.max) - 2, 3),
    (Int(UInt16.max), 3),
    (Int(UInt16.max) + 1, 5),
    (Int(UInt32.max), 5),
    (Int(UInt32.max) + 1, 9),
    (Int.max, 9),
]) func parsing(value: Int, expectedBytes: Int) throws {
    let varInt = VarInt(value)
    let data = varInt.data
    #expect(data.count == expectedBytes)

    // Swift Binary Parsing
    let data2 = try withTemporaryAllocation(byteCount: varInt.binarySize, alignment: 1) { span in
        try varInt.encode(into: &span)
        return Data(span)
    }
    #expect(data2 == data)

    let data3 = try Data(capacity: varInt.binarySize) { out in
        try varInt.encode(into: &out)
    }
    #expect(data3 == data)

    // Adding some garbage
    let dataPlus = data + Data([0xff, 0xff, 0xff, 0xff, 0xff])
    let varInt2 = try VarInt(dataPlus)
    #expect(varInt == varInt2)

    // Swift Binary Parsing
    // var input = ParserSpan(dataPlus.bytes)
    // let varInt3 = try VarInt(parsing: &input)
    let varInt3 = try dataPlus.withParserSpan { input in
        try VarInt(parsing: &input, format: nil) // TODO: Remove format nil
    }
    #expect(varInt == varInt3)

    let varInt4 = try VarInt(dataPlus)
    #expect(varInt == varInt4)
}
