import XCTest
@testable import Bitcoin

final class ScriptOperationTests: XCTestCase {

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
