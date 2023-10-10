import XCTest
@testable import Bitcoin

final class ScriptOperationTests: XCTestCase {

    func testDataOps() {
        let vectors = [
            // zero, constant
            ([Int](), [ScriptOperation.zero, .constant(1), .constant(2), .constant(3), .constant(4), .constant(5), .constant(6), .constant(7), .constant(8), .constant(9), .constant(10), .constant(11), .constant(12), .constant(13), .constant(14), .constant(15), .constant(16)], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
            ([], [.pushBytes(try! ScriptNumber(17).data)], [17]),
        ]

        for v in vectors {
            var stack = [Data].withConstants(v.0)
            XCTAssertNoThrow(try ParsedScript(v.1).run(&stack))
            XCTAssertEqual(stack, .withConstants(v.2))
        }

        // Data vectors

        let lengthyData = Data(repeating: 0xff, count: 75)

        let vectors2 = [
            // pushBytes
            ([Data](), [ScriptOperation.pushBytes(lengthyData)], [lengthyData]),
        ]

        for v in vectors2 {
            var stack = v.0
            XCTAssertNoThrow(try ParsedScript(v.1).run(&stack))
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
            ([1, 2, 3, 1], [.pick], [1, 2, 3, 3]),
            ([1, 2, 3, 2], [.pick], [1, 2, 3, 2]),
            ([1, 2, 3, 3], [.pick], [1, 2, 3, 1]),
            // roll
            ([1, 2, 3, 1], [.roll], [1, 2, 3]),
            ([1, 2, 3, 2], [.roll], [1, 3, 2]),
            ([1, 2, 3, 3], [.roll], [2, 3, 1]),
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
            XCTAssertNoThrow(try ParsedScript(v.1).run(&stack))
            XCTAssertEqual(stack, .withConstants(v.2))
        }
    }
}
