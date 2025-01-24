import Foundation
import Testing
import BitcoinCrypto

struct BinaryCodableTests {

    @Test func trivialRoundtrip() throws {
        let a = Int.random(in: Int.min ... Int.max)
        var visitor = BinarySizeVisitor()
        visitor.count(a)
        var encoder = BinaryEncoder(count: visitor.size)
        encoder.put(a)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let a2: Int = try decoder.take()
        #expect(a == a2)
    }

    @Test func customStructRoundtrip() throws {
        let s = CustomStruct(int: .max, intArray: [0, 1, 2], data: .init([3, 4, 5, 6]), uInt64: .max)
        var visitor = BinarySizeVisitor()
        visitor.count(s)
        var encoder = BinaryEncoder(count: visitor.size)
        encoder.put(s)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let s2: CustomStruct = try decoder.take()
        #expect(s == s2)
    }

    @Test func nestedStructRoundtrip() throws {
        let child = CustomStruct(int: .max, intArray: [0, 1, 2], data: .init([3, 4, 5, 6]), uInt64: .max)
        let parent = ParentStruct(int1: .max, child: child, int2: .max / 2, children: [child, child, child], int3: .max / 3)
        var visitor = BinarySizeVisitor()
        visitor.count(parent)
        var encoder = BinaryEncoder(count: visitor.size)
        encoder.put(parent)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let parent2: ParentStruct = try decoder.take()
        #expect(parent == parent2)
    }
}

private struct ParentStruct: Equatable {
    var int1: Int
    var child: CustomStruct
    var int2: Int
    var children: [CustomStruct]
    var int3: Int
}

extension ParentStruct: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        int1 = try decoder.take()
        child = try decoder.take()
        int2 = try decoder.take()
        children = try decoder.take()
        int3 = try decoder.take()
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.put(int1)
        encoder.put(child)
        encoder.put(int2)
        encoder.put(children)
        encoder.put(int3)
    }
    
    func reportSize(to visitor: inout BinarySizeVisitor) {
        visitor.count(int1)
        visitor.count(child)
        visitor.count(int2)
        visitor.count(children)
        visitor.count(int3)
    }
}

private struct CustomStruct: Equatable {
    var int: Int
    var intArray: [Int]
    var data: Data
    var uInt64: UInt64
}

extension CustomStruct: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        int = try decoder.take()
        intArray = try decoder.take()
        let len: VarInt = try decoder.take()
        decoder.setLimit(len.value)
        data = try decoder.take()
        decoder.resetLimit()
        uInt64 = try decoder.take()
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.put(int)
        encoder.put(intArray)
        encoder.put(VarInt(data.count))
        encoder.put(data)
        encoder.put(uInt64)
    }
    
    func reportSize(to visitor: inout BinarySizeVisitor) {
        visitor.count(int)
        visitor.count(intArray)
        visitor.count(VarInt(data.count))
        visitor.countSize(data.count)
        visitor.count(uInt64)
    }
}
