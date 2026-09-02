import Foundation
import Testing
import BitcoinCrypto

struct BinaryCodableTests {

    @Test func trivialRoundtrip() throws {
        let a = Int.random(in: Int.min ... Int.max)
        var counter = BinarySizeCounter()
        counter.count(Int.self)

        let data = Data(capacity: counter.size) { out in
            out.append(a, as: Int.self, .littleEndian)
        }

        var decoder = BinaryDecoder(data)
        let a2: Int = try decoder.decode()
        #expect(a == a2)
    }

    @Test func customStructRoundtrip() throws {
        let s = CustomStruct(int: .max, intArray: [0, 1, 2], dataField: .init([3, 4, 5, 6]), uInt64: .max)
        var counter = BinarySizeCounter()
        counter.count(s)

        /*
        var encoder = BinaryEncoder(counter)
        encoder.encode(s)
        let data = encoder.data
        */
        let data = try Data(capacity: counter.size) { out in
            try s.encode(into: &out)
        }

        var decoder = BinaryDecoder(data)
        let s2: CustomStruct = try decoder.decode()
        #expect(s.intArray == s2.intArray)

        print("\([UInt8](s.dataField))")
        print("\([UInt8](s2.dataField))")
        print("s v s2")
        #expect(s.dataField == s2.dataField)
        #expect(s == s2)
    }

    @Test func nestedStructRoundtrip() throws {
        let child = CustomStruct(int: .max, intArray: [0, 1, 2], dataField: .init([3, 4, 5, 6]), uInt64: .max)
        let parent = ParentStruct(int1: .max, child: child, int2: .max / 2, children: [child, child, child], int3: .max / 3)
        var counter = BinarySizeCounter()
        counter.count(parent)
        /*
        var encoder = BinaryEncoder(counter)
        encoder.encode(parent)
        let data = encoder.data
        */
        let data = try Data(capacity: counter.size) { out in
            try parent.encode(into: &out)
        }
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
    init(from decoder: inout BinaryDecoder, format: Never?) throws {
        int1 = try decoder.decode()
        child = try decoder.decode()
        int2 = (try decoder.decode() as Int).byteSwapped // Stored as big endian
        children = try [CustomStruct](from: &decoder, format: nil)
        int3 = try decoder.decode()
    }

    func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(Int.self)
        counter.count(child)
        counter.count(Int.self)
        counter.count(children)
        counter.count(Int.self)
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(int1, as: Int.self, .littleEndian)
        try child.encode(into: &out)
        out.append(int2, as: Int.self, .bigEndian)
        try children.encode(into: &out)
        out.append(int3, as: Int.self, .littleEndian)
    }

    /*
    func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(int1)
        encoder.encode(child)
        encoder.encode(int2)
        encoder.encode(children)
        encoder.encode(int3)
    }
    */
}

private struct CustomStruct: Equatable {
    var int: Int
    var intArray: [Int]
    var dataField: Data
    var uInt64: UInt64
}

extension CustomStruct: BinaryCodable {
    init(from decoder: inout BinaryDecoder, format: Never?) throws {
        int = try decoder.decode()

        let count: VarInt = try decoder.decode()
        intArray = [Int](repeating: 0, count: count.value)
        for i in intArray.indices {
            intArray[i] = try decoder.decode()
        }

        dataField = try decoder.decode(variable: true)
        uInt64 = try decoder.decode()
    }

    func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(Int.self)
        counter.count(intArray)
        counter.count(dataField, variable: true)
        counter.count(UInt64.self)
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(int, as: Int.self, .littleEndian)

        try VarInt(intArray.count).encode(into: &out)
        for i in intArray {
            out.append(i, as: Int.self, .littleEndian)
        }

        try VarInt(dataField.count).encode(into: &out)
        out.append(contentsOf: dataField)

        out.append(uInt64, as: UInt64.self, .littleEndian)
    }

    /*
    func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(int)
        encoder.encode(intArray)
        encoder.encode(dataField, variable: true)
        encoder.encode(uInt64)
    }
    */
}

