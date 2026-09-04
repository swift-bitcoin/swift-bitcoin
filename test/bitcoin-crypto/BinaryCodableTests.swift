import Foundation
import BinaryParsing
import Testing
import BitcoinCrypto

struct BinaryCodableTests {

    @Test func trivialRoundtrip() throws {
        let a = Int.random(in: Int.min ... Int.max)
        var counter = BinarySizeCounter()
        counter.count(Int.self)

        let data = Data(capacity: counter.size) { out in
            out.append(Int64(a), as: Int64.self, .littleEndian)
        }
        let a2: Int = try data.withParserSpan { input in
            try Int(parsing: &input, storedAsLittleEndian: Int64.self)
        }
        #expect(a == a2)
    }

    @Test func customStructRoundtrip() throws {
        let s = CustomStruct(int: .max, intArray: [0, 1, 2], dataField: .init([3, 4, 5, 6]), uInt64: .max)
        var counter = BinarySizeCounter()
        counter.count(s)

        let data = try Data(capacity: counter.size) { out in
            try s.encode(into: &out)
        }

        let s2 = try data.withParserSpan { input in
            try CustomStruct(parsing: &input)
        }
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
        let data = try Data(capacity: counter.size) { out in
            try parent.encode(into: &out)
        }

        let parent2 = try data.withParserSpan { input in
            try ParentStruct(parsing: &input)
        }
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
    init(parsing input: inout ParserSpan, format: Never?) throws {
        int1 = Int(try Int64(parsingLittleEndian: &input))
        child = try CustomStruct(parsing: &input)
        int2 = Int(try Int64(parsingBigEndian: &input))
        children = try [CustomStruct](parsing: &input)
        int3 = Int(try Int64(parsingLittleEndian: &input))
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
}

private struct CustomStruct: Equatable {
    var int: Int
    var intArray: [Int]
    var dataField: Data
    var uInt64: UInt64
}

extension CustomStruct: BinaryCodable {
    init(parsing input: inout ParserSpan, format: BinaryFormat?) throws {
        int = Int(try Int64(parsingLittleEndian: &input))

        let arrayCount = try VarInt(parsing: &input)
        intArray = [Int](repeating: 0, count: arrayCount.value)
        for i in intArray.indices {
            intArray[i] = try Int(parsing: &input, storedAsLittleEndian: Int64.self)
        }

        let dataCount = try VarInt(parsing: &input)
        dataField = try Data(parsing: &input, byteCount: dataCount.value)
        uInt64 = try UInt64(parsingLittleEndian: &input)
    }

    func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(Int.self)
        VarInt(intArray.count).countBytes(into: &counter)
        counter.countSize(intArray.count * MemoryLayout<Int64>.size)
        counter.count(dataField, variable: true)
        counter.count(UInt64.self)
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(int, as: Int.self, .littleEndian)

        try VarInt(intArray.count).encode(into: &out)
        for i in intArray {
            out.append(Int64(i), as: Int64.self, .littleEndian)
        }

        try VarInt(dataField.count).encode(into: &out)
        out.append(contentsOf: dataField)

        out.append(uInt64, as: UInt64.self, .littleEndian)
    }
}

