import XCTest
@testable import Bitcoin

final class ScriptOperationTests: XCTestCase {

    func testDataOps() {
        let vectors = [
            // oneNegate, zero, constant
            ([Int](), [ScriptOperation.oneNegate , .zero, .constant(1), .constant(2), .constant(3), .constant(4), .constant(5), .constant(6), .constant(7), .constant(8), .constant(9), .constant(10), .constant(11), .constant(12), .constant(13), .constant(14), .constant(15), .constant(16)], [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
            ([], [.pushBytes(try! ScriptNumber(17).data)], [17]),
        ]

        for v in vectors {
            var stack = [Data].withConstants(v.0)
            XCTAssertNoThrow(try BitcoinScript(v.1).run(&stack))
            XCTAssertEqual(stack, .withConstants(v.2))
        }

        // Data vectors

        let lengthyLength = 75
        let lengthyData = Data(repeating: 0xff, count: lengthyLength)
        let lengthyData2 = Data(repeating: 0xff, count: lengthyLength - 1) + Data([0x00])

        let vectors2 = [
            // pushBytes
            ([Data](), [ScriptOperation.pushBytes(lengthyData)], [lengthyData]),
            // size
            ([Data](), [ScriptOperation.pushBytes(lengthyData), .size], [lengthyData, try! ScriptNumber(lengthyLength).data]),
            // equal
            ([Data](), [ScriptOperation.pushBytes(lengthyData), ScriptOperation.pushBytes(lengthyData), .equal], [ScriptNumber.one.data]),
            ([Data](), [ScriptOperation.pushBytes(lengthyData), ScriptOperation.pushBytes(lengthyData2), .equal, .constant(1)], [ScriptNumber.zero.data, ScriptNumber.one.data]),
        ]

        for v in vectors2 {
            var stack = v.0
            XCTAssertNoThrow(try BitcoinScript(v.1).run(&stack))
            XCTAssertEqual(stack, v.2)
        }
    }

    func testCryptographyOps() {
        let helloData = "hello".data(using: .ascii)!
        let expectedRIPEMD160 = Data([0x10, 0x8f, 0x07, 0xb8, 0x38, 0x24, 0x12, 0x61, 0x2c, 0x04, 0x8d, 0x07, 0xd1, 0x3f, 0x81, 0x41, 0x18, 0x44, 0x5a, 0xcd])
        let expectedSHA1 = Data([0xaa, 0xf4, 0xc6, 0x1d, 0xdc, 0xc5, 0xe8, 0xa2, 0xda, 0xbe, 0xde, 0x0f, 0x3b, 0x48, 0x2c, 0xd9, 0xae, 0xa9, 0x43, 0x4d])
        let expectedSHA256 = Data([0x2c, 0xf2, 0x4d, 0xba, 0x5f, 0xb0, 0xa3, 0x0e, 0x26, 0xe8, 0x3b, 0x2a, 0xc5, 0xb9, 0xe2, 0x9e, 0x1b, 0x16, 0x1e, 0x5c, 0x1f, 0xa7, 0x42, 0x5e, 0x73, 0x04, 0x33, 0x62, 0x93, 0x8b, 0x98, 0x24])
        let expectedHash160 = Data([0xb6, 0xa9, 0xc8, 0xc2, 0x30, 0x72, 0x2b, 0x7c, 0x74, 0x83, 0x31, 0xa8, 0xb4, 0x50, 0xf0, 0x55, 0x66, 0xdc, 0x7d, 0x0f])
        let expectedHash256 = Data([0x95, 0x95, 0xc9, 0xdf, 0x90, 0x07, 0x51, 0x48, 0xeb, 0x06, 0x86, 0x03, 0x65, 0xdf, 0x33, 0x58, 0x4b, 0x75, 0xbf, 0xf7, 0x82, 0xa5, 0x10, 0xc6, 0xcd, 0x48, 0x83, 0xa4, 0x19, 0x83, 0x3d, 0x50])

        let vectors = [
            // ripemd160
            ([helloData], [ScriptOperation.ripemd160], [expectedRIPEMD160]),
            // sha1
            ([helloData], [.sha1], [expectedSHA1]),
            // sha256
            ([helloData], [.sha256], [expectedSHA256]),
            // hash160
            ([helloData], [.hash160], [expectedHash160]),
            // hash256
            ([helloData], [.hash256], [expectedHash256]),
        ]

        for v in vectors {
            var stack = v.0
            XCTAssertNoThrow(try BitcoinScript(v.1).run(&stack))
            XCTAssertEqual(stack, v.2)
        }
    }

    func testStackOps() {
        let vectors = [
            // toAltStack / fromAltStack
            ([1], [ScriptOperation.toAltStack, .zero, .fromAltStack], [0, 1]),
            // ifDup
            ([0], [.ifDup, .constant(1)], [0, 1]),
            ([1], [.ifDup], [1, 1]),
            // depth
            ([1, 2, 3], [.depth], [1, 2, 3, 3]),
            ([], [.depth, .constant(1)], [0, 1]),
            // drop
            ([1, 2], [.drop], [1]),
            // dup
            ([1], [.dup], [1, 1]),
            // nip
            ([1, 2], [.nip], [2]),
            // over
            ([1, 2], [.over], [1, 2, 1]),
            // pick
            ([1, 2, 3, 0], [.pick], [1, 2, 3, 3]),
            ([1, 2, 3, 1], [.pick], [1, 2, 3, 2]),
            ([1, 2, 3, 2], [.pick], [1, 2, 3, 1]),
            // roll
            ([1, 2, 3, 0], [.roll], [1, 2, 3]),
            ([1, 2, 3, 1], [.roll], [1, 3, 2]),
            ([1, 2, 3, 2], [.roll], [2, 3, 1]),
            // rot
            ([1, 2, 3], [.rot], [2, 3, 1]),
            ([1, 2], [.swap], [2, 1]),
            // tuck
            ([1, 2], [.tuck], [2, 1, 2]),
            // twoDrop
            ([1, 2], [.twoDrop], []),
            // twoDup
            ([1, 2], [.twoDup], [1, 2, 1, 2]),
            ([1, 2, 3], [.twoDup], [1, 2, 3, 2, 3]),
            // threeDup
            ([1, 2, 3], [.threeDup], [1, 2, 3, 1, 2, 3]),
            // twoOver
            ([1, 2, 3, 4], [.twoOver], [1, 2, 3, 4, 1, 2]),
            // twoRot
            ([1, 2, 3, 4, 5, 6], [.twoRot], [3, 4, 5, 6, 1, 2]),
            // twoSwap
            ([1, 2, 3, 4], [.twoSwap], [3, 4, 1, 2]),
        ]

        for v in vectors {
            var stack = [Data].withConstants(v.0)
            XCTAssertNoThrow(try BitcoinScript(v.1).run(&stack))
            XCTAssertEqual(stack, .withConstants(v.2))
        }
    }

    func testArithmeticOps() {
        let vectors = [
            // oneAdd
            ([1], [ScriptOperation.oneAdd], [2]),
            // oneSub
            ([2], [.oneSub], [1]),
            // negate
            ([-1], [.negate], [1]),
            ([1], [.negate], [-1]),
            // abs
            ([-1], [.abs], [1]),
            ([1], [.abs], [1]),
            // not
            ([0], [.not], [1]),
            ([1], [.not, .constant(1)], [0, 1]),
            ([2], [.not, .constant(1)], [0, 1]),
            // zeroNotEqual
            ([0], [.zeroNotEqual, .constant(1)], [0, 1]),
            ([1], [.zeroNotEqual], [1]),
            ([2], [.zeroNotEqual], [1]),
            // add
            ([1, 2], [.add], [3]),
            // sub
            ([3, 2], [.sub], [1]),
            // boolAnd
            ([0, 0], [.boolAnd, .constant(1)], [0, 1]),
            ([1, 0], [.boolAnd, .constant(1)], [0, 1]),
            ([0, 1], [.boolAnd, .constant(1)], [0, 1]),
            ([1, 1], [.boolAnd], [1]),
            ([1, 2], [.boolAnd], [1]),
            // boolOr
            ([0, 0], [.boolOr, .constant(1)], [0, 1]),
            ([1, 0], [.boolOr], [1]),
            ([0, 1], [.boolOr], [1]),
            ([1, 1], [.boolOr], [1]),
            ([1, 2], [.boolOr], [1]),
            // numEqual
            ([0, 0], [.numEqual], [1]),
            ([1, 1], [.numEqual], [1]),
            ([0, 1], [.numEqual, .constant(1)], [0, 1]),
            ([1, 2], [.numEqual, .constant(1)], [0, 1]),
            // numNotEqual
            ([0, 0], [.numNotEqual, .constant(1)], [0, 1]),
            ([1, 1], [.numNotEqual, .constant(1)], [0, 1]),
            ([0, 1], [.numNotEqual], [1]),
            ([1, 2], [.numNotEqual], [1]),
            // lessThan
            ([1, 2], [.lessThan], [1]),
            ([1, 1], [.lessThan, .constant(1)], [0, 1]),
            ([2, 1], [.lessThan, .constant(1)], [0, 1]),
            // greaterThan
            ([1, 2], [.greaterThan, .constant(1)], [0, 1]),
            ([1, 1], [.greaterThan, .constant(1)], [0, 1]),
            ([2, 1], [.greaterThan], [1]),
            // lessThanOrEqual
            ([1, 2], [.lessThanOrEqual], [1]),
            ([1, 1], [.lessThanOrEqual], [1]),
            ([2, 1], [.lessThanOrEqual, .constant(1)], [0, 1]),
            // greaterThanOrEqual
            ([1, 2], [.greaterThanOrEqual, .constant(1)], [0, 1]),
            ([1, 1], [.greaterThanOrEqual], [1]),
            ([2, 1], [.greaterThanOrEqual], [1]),
            // min
            ([1, 2], [.min], [1]),
            ([2, 1], [.min], [1]),
            // max
            ([1, 2], [.max], [2]),
            ([2, 1], [.max], [2]),
            // within
            ([1, 1, 3], [.within], [1]),
            ([2, 1, 3], [.within], [1]),
            ([3, 1, 3], [.within, .constant(1)], [0, 1]),
            ([4, 1, 3], [.within, .constant(1)], [0, 1]),
            // equal
            ([1, 1], [.equal], [1]),
            ([0, 0], [.equal], [1]),
            ([-1, -1], [.equal], [1]),
            ([1, 0], [.equal, .constant(1)], [0, 1]),
            ([0, 1], [.equal, .constant(1)], [0, 1]),
            ([-1, 1], [.equal, .constant(1)], [0, 1]),
            ([1, -1], [.equal, .constant(1)], [0, 1]),
        ]

        for v in vectors {
            var stack = [Data].withConstants(v.0)
            XCTAssertNoThrow(try BitcoinScript(v.1).run(&stack))
            XCTAssertEqual(stack, .withConstants(v.2))
        }
    }
}
