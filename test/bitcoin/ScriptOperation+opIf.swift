import XCTest
@testable import Bitcoin

final class OpIfTests: XCTestCase {

    func testIf() {
        // If branch
        //var script = Script([.constant(1), .if, .constant(2), .else, .constant(3), .endIf]
        var script = ParsedScript([.constant(1), .if, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // If branch (not activated)
        script = ParsedScript([.zero, .if, .constant(2), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])
    }

    func testNotIf() {
        // Not-if (activated)
        var script = ParsedScript([.zero, .notIf, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // Not-if (not activated)
        script = ParsedScript([.constant(1), .notIf, .constant(2), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])
    }

    func testElse() {
        // If branch
        //var script = Script([.constant(1), .if, .constant(2), .else, .constant(3), .endIf]
        var script = ParsedScript([.constant(1), .if, .constant(2), .else, .constant(3), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // If branch (not activated), else branch (activated)
        script = ParsedScript([.zero, .if, .constant(2), .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // Not-If branch (activated), else branch (not activated)
        script = ParsedScript([.zero, .notIf, .constant(2), .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // Not-If branch (not activated), else branch (activated)
        script = ParsedScript([.constant(1), .notIf, .constant(2), .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])
    }

    func testNestedIf() {
        // If branch
        var script = ParsedScript([.constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // 2 level nesting
        script = ParsedScript([.constant(1), .if, .constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])
    }

    func testNestedElse() {
        // Inner else
        var script = ParsedScript([.constant(1), .if, .zero, .if, .constant(2), .else, .constant(3) , .endIf, .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, inner else
        script = ParsedScript([.constant(1), .if, .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3) , .endIf, .endIf, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 1 level nesting, outer else
        script = ParsedScript([.zero, .if, .constant(1), .if, .constant(2), .endIf, .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, outer else
        script = ParsedScript([.zero, .if, .constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf, .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, middle else
        script = ParsedScript([.constant(1), .if, .zero, .if, .constant(1), .if, .constant(2), .endIf, .else, .constant(3), .endIf, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // 2 level nesting, alternate 1
        script = ParsedScript([.zero, .if, .constant(1), .if, .constant(1), .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([5])])

        // alternate 2
        script = ParsedScript([.constant(1), .if, .zero, .if, .constant(1), .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([4])])

        // alternate 2
        script = ParsedScript([.constant(1), .if, .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])
    }

    func testEmptyBranches() {
        // Empty if branch
        var script = ParsedScript([.constant(1), .if, .else, .constant(3), .endIf])
        var stack = [Data]()
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])

        // Empty if branch (negative)
        script = ParsedScript([.zero, .if, .else, .constant(3), .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([3])])

        // Empty else branch (activated)
        script = ParsedScript([.zero, .if, .constant(2), .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])

        // Empty else branch (not activated)
        script = ParsedScript([.constant(1), .if, .constant(2), .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [Data([2])])

        // Empty branches
        script = ParsedScript([.constant(1), .if, .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])

        // Empty branches (negative)
        script = ParsedScript([.zero, .if, .else, .endIf])
        stack = []
        XCTAssertNoThrow(try script.run(&stack))
        XCTAssertEqual(stack, [])
    }

    func testMinimalif() {
        // True-ish value
        var script = ParsedScript([.constant(2), .if, .constant(2), .else, .constant(3), .endIf], version: .witnessV0)
        var stack = [Data]()
        XCTAssertThrowsError(try script.run(&stack))

        // Falsish value
        script = ParsedScript([.pushBytes(Data([0])), .if, .constant(2), .else, .constant(3), .endIf], version: .witnessV0)
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // Falsish value not-if
        script = ParsedScript([.pushBytes(Data([0])), .notIf, .constant(2), .else, .constant(3), .endIf], version: .witnessV0)
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // true-ish value not-if
        script = ParsedScript([.constant(2), .notIf, .constant(2), .else, .constant(3), .endIf], version: .witnessV0)
        stack = []
        XCTAssertThrowsError(try script.run(&stack))
    }

    func testVerIf() {
        var script = ParsedScript([.constant(1), .if, .verIf, .else, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertThrowsError(try script.run(&stack))

        script = ParsedScript([.constant(1), .if, .constant(2), .else, .verIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = ParsedScript([.zero, .if, .verIf, .else, .constant(2), .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))
    }

    func testOpSuccess() {
        // TODO: When tapscript is implemented…
        // ```
        // var script = ParsedScript([.constant(1), .if, .constant(2), .else, .success(80)])
        // var stack = [Data]()
        // XCTAssertNoThrow(try script.run(&stack))
        //
        // script = ParsedScript([.constant(1), .if, .success(80), .else, .constant(2), .endIf])
        // stack = []
        // XCTAssertNoThrow(try script.run(&stack))
        // ```
    }

    func testIfMalformed() {
        // Missing endif
        var script = ParsedScript([.constant(1), .if, .constant(1), .if, .constant(2), .endIf])
        var stack = [Data]()
        XCTAssertThrowsError(try script.run(&stack))

        // Too many endifs
        script = ParsedScript([.constant(1), .if, .constant(2), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = ParsedScript([.zero, .if, .constant(2), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // Too many else's
        script = ParsedScript([.constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // Too many else's (else branch evaluated)
        script = ParsedScript([.zero, .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        // interlaced
        script = ParsedScript([
            .constant(1), .if, .constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = ParsedScript([
            .zero, .if, .constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))

        script = ParsedScript([
            .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf])
        stack = []
        XCTAssertThrowsError(try script.run(&stack))
    }
}
