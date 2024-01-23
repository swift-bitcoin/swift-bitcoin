import XCTest
@testable import Bitcoin

final class OpIfTests: XCTestCase {

    func testIf() {
        // If branch
        //var script = Script([.constant(1), .if, .constant(2), .else, .constant(3), .endIf]
        var script = BitcoinScript([.constant(1), .if, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // If branch (not activated)
        script = BitcoinScript([.zero, .if, .constant(2), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])
    }

    func testNotIf() {
        // Not-if (activated)
        var script = BitcoinScript([.zero, .notIf, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // Not-if (not activated)
        script = BitcoinScript([.constant(1), .notIf, .constant(2), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])
    }

    func testElse() {
        // If branch
        //var script = Script([.constant(1), .if, .constant(2), .else, .constant(3), .endIf]
        var script = BitcoinScript([.constant(1), .if, .constant(2), .else, .constant(3), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // If branch (not activated), else branch (activated)
        script = BitcoinScript([.zero, .if, .constant(2), .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // Not-If branch (activated), else branch (not activated)
        script = BitcoinScript([.zero, .notIf, .constant(2), .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // Not-If branch (not activated), else branch (activated)
        script = BitcoinScript([.constant(1), .notIf, .constant(2), .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])
    }

    func testNestedIf() {
        // If branch
        var script = BitcoinScript([.constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // 2 level nesting
        script = BitcoinScript([.constant(1), .if, .constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])
    }

    func testNestedElse() {
        // Inner else
        var script = BitcoinScript([.constant(1), .if, .zero, .if, .constant(2), .else, .constant(3) , .endIf, .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, inner else
        script = BitcoinScript([.constant(1), .if, .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3) , .endIf, .endIf, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 1 level nesting, outer else
        script = BitcoinScript([.zero, .if, .constant(1), .if, .constant(2), .endIf, .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, outer else
        script = BitcoinScript([.zero, .if, .constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf, .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, middle else
        script = BitcoinScript([.constant(1), .if, .zero, .if, .constant(1), .if, .constant(2), .endIf, .else, .constant(3), .endIf, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, alternate 1
        script = BitcoinScript([.zero, .if, .constant(1), .if, .constant(1), .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([5])])

        // alternate 2
        script = BitcoinScript([.constant(1), .if, .zero, .if, .constant(1), .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([4])])

        // alternate 2
        script = BitcoinScript([.constant(1), .if, .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])
    }

    func testEmptyBranches() {
        // Empty if branch
        var script = BitcoinScript([.constant(1), .if, .else, .constant(3), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])

        // Empty if branch (negative)
        script = BitcoinScript([.zero, .if, .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // Empty else branch (activated)
        script = BitcoinScript([.zero, .if, .constant(2), .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])

        // Empty else branch (not activated)
        script = BitcoinScript([.constant(1), .if, .constant(2), .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // Empty branches
        script = BitcoinScript([.constant(1), .if, .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])

        // Empty branches (negative)
        script = BitcoinScript([.zero, .if, .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])
    }

    func testMinimalif() {
        // True-ish value
        var script = BitcoinScript([.constant(2), .if, .constant(2), .else, .constant(3), .endIf], sigVersion: .witnessV0)
        var stack = [Data]()
        XCTAssertThrowsError(try script.run(&stack))

        // Falsish value
        script = BitcoinScript([.pushBytes(Data([0])), .if, .constant(2), .else, .constant(3), .endIf], sigVersion: .witnessV0)
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // Falsish value not-if
        script = BitcoinScript([.pushBytes(Data([0])), .notIf, .constant(2), .else, .constant(3), .endIf], sigVersion: .witnessV0)
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // true-ish value not-if
        script = BitcoinScript([.constant(2), .notIf, .constant(2), .else, .constant(3), .endIf], sigVersion: .witnessV0)
        stack = []
        XCTAssertThrowsError(try script.run(&stack))
    }

    func testVerIf() {
        var script = BitcoinScript([.constant(1), .if, .verIf, .else, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertThrowsError(try script.run(&stack))

        script = BitcoinScript([.constant(1), .if, .constant(2), .else, .verIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = BitcoinScript([.zero, .if, .verIf, .else, .constant(2), .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))
    }

    func testOpSuccess() {
        var script = BitcoinScript([.constant(1), .if, .constant(2), .else, .success(80)], sigVersion: .witnessV1)
        var stack = [Data]()
        XCTAssertNoThrow(try script.runV1(&stack))

        script = BitcoinScript([.constant(1), .if, .success(80), .else, .constant(2), .endIf], sigVersion: .witnessV1)
        stack = []
        XCTAssertNoThrow(try script.runV1(&stack))
    }

    func testIfMalformed() {
        // Missing endif
        var script = BitcoinScript([.constant(1), .if, .constant(1), .if, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertThrowsError(try script.run(&stack))

        // Too many endifs
        script = BitcoinScript([.constant(1), .if, .constant(2), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = BitcoinScript([.zero, .if, .constant(2), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // Too many else's
        script = BitcoinScript([.constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // Too many else's (else branch evaluated)
        script = BitcoinScript([.zero, .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // interlaced
        script = BitcoinScript([
            .constant(1), .if, .constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = BitcoinScript([
            .zero, .if, .constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = BitcoinScript([
            .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))
    }
}
