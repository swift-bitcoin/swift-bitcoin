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
        let expectedRIPEMD160 = Data(hex: "108f07b8382412612c048d07d13f814118445acd")!
        let expectedSHA1 = Data(hex: "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")!
        let expectedSHA256 = Data(hex: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")!
        let expectedHash160 = Data(hex: "b6a9c8c230722b7c748331a8b450f05566dc7d0f")!
        let expectedHash256 = Data(hex: "9595c9df90075148eb06860365df33584b75bff782a510c6cd4883a419833d50")!

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
