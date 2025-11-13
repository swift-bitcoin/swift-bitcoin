import Foundation
import Testing
@testable import BitcoinCrypto

#if canImport(BinaryParsing) // Restore once BinaryParsing supports iOS ( >= 0.0.2)

import BinaryParsing

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
    let dataPlus = data + Data([0xff, 0xff, 0xff, 0xff, 0xff])
    let varInt2 = try VarInt(dataPlus)
    #expect(varInt == varInt2)
    var input = ParserSpan(dataPlus.bytes)
    let varInt3 = try VarInt(parsing: &input)
    #expect(varInt == varInt3)
}

#endif
