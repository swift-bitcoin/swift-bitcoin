import Foundation
import Testing
import BitcoinCrypto

struct BinaryCodableTests {

    @Test func trivialRoundtrip() throws {
        let a = Int.random(in: Int.min ... Int.max)
        var counter = BinaryEncodingSizeCounter()
        counter.count(a)
        var encoder = BinaryEncoder(counter)
        encoder.encode(a)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let a2: Int = try decoder.decode()
        #expect(a == a2)
    }

    @Test func customStructRoundtrip() throws {
        let s = CustomStruct(int: .max, intArray: [0, 1, 2], data: .init([3, 4, 5, 6]), uInt64: .max)
        var counter = BinaryEncodingSizeCounter()
        counter.count(s)
        var encoder = BinaryEncoder(counter)
        encoder.encode(s)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let s2: CustomStruct = try decoder.decode()
        #expect(s == s2)
    }

    @Test func nestedStructRoundtrip() throws {
        let child = CustomStruct(int: .max, intArray: [0, 1, 2], data: .init([3, 4, 5, 6]), uInt64: .max)
        let parent = ParentStruct(int1: .max, child: child, int2: .max / 2, children: [child, child, child], int3: .max / 3)
        var counter = BinaryEncodingSizeCounter()
        counter.count(parent)
        var encoder = BinaryEncoder(counter)
        encoder.encode(parent)
        let data = encoder.data
        var decoder = BinaryDecoder(data)
        let parent2: ParentStruct = try decoder.decode()
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
        int1 = try decoder.decode()
        child = try decoder.decode()
        int2 = try decoder.decode()
        children = try decoder.decode()
        int3 = try decoder.decode()
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(int1)
        encoder.encode(child)
        encoder.encode(int2)
        encoder.encode(children)
        encoder.encode(int3)
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(int1)
        counter.count(child)
        counter.count(int2)
        counter.count(children)
        counter.count(int3)
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
        int = try decoder.decode()
        intArray = try decoder.decode()
        data = try decoder.decode(variable: true)
        uInt64 = try decoder.decode()
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(int)
        encoder.encode(intArray)
        encoder.encode(data, variable: true)
        encoder.encode(uInt64)
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(int)
        counter.count(intArray)
        counter.count(data, variable: true)
        counter.count(uInt64)
    }
}
