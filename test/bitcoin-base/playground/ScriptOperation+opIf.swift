import Testing
import Foundation
import BitcoinBase

struct OpIfTests {

    @Test("If branch")
    func ifBranch() throws {
        // If branch
        //var script = Script([.constant(1), .if, .constant(2), .else, .constant(3), .endIf]
        var script = BitcoinScript([.constant(1), .if, .constant(2), .endIf])
        var stack = [Data]()
        try script.run(&stack)
        #expect(stack == [Data([2])])

        // If branch (not activated)
        script = [.zero, .if, .constant(2), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [])
    }

    @Test("Not If")
    func notIf() throws {
        // Not-if (activated)
        var script = BitcoinScript([.zero, .notIf, .constant(2), .endIf])
        var stack = [Data]()
        try script.run(&stack)
        #expect(stack == [Data([2])])

        // Not-if (not activated)
        script = [.constant(1), .notIf, .constant(2), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [])
    }

    @Test("If Else")
    func ifElse() throws {
        // If branch
        //var script = Script([.constant(1), .if, .constant(2), .else, .constant(3), .endIf]
        var script = BitcoinScript([.constant(1), .if, .constant(2), .else, .constant(3), .endIf])
        var stack = [Data]()
        try script.run(&stack)
        #expect(stack == [Data([2])])

        // If branch (not activated), else branch (activated)
        script = [.zero, .if, .constant(2), .else, .constant(3), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // Not-If branch (activated), else branch (not activated)
        script = [.zero, .notIf, .constant(2), .else, .constant(3), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([2])])

        // Not-If branch (not activated), else branch (activated)
        script = [.constant(1), .notIf, .constant(2), .else, .constant(3), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])
    }

    @Test("Nested If")
    func nestedIf() throws {
        // If branch
        var script = BitcoinScript([.constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf])
        var stack = [Data]()
        try script.run(&stack)
        #expect(stack == [Data([2])])

        // 2 level nesting
        script = [.constant(1), .if, .constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([2])])
    }

    @Test("Nested Else")
    func nestedElse() throws {
        // Inner else
        var script = BitcoinScript([.constant(1), .if, .zero, .if, .constant(2), .else, .constant(3) , .endIf, .endIf])
        var stack = [Data]()
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // 2 level nesting, inner else
        script = [.constant(1), .if, .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3) , .endIf, .endIf, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // 1 level nesting, outer else
        script = [.zero, .if, .constant(1), .if, .constant(2), .endIf, .else, .constant(3), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // 2 level nesting, outer else
        script = [.zero, .if, .constant(1), .if, .constant(1), .if, .constant(2), .endIf, .endIf, .else, .constant(3), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // 2 level nesting, middle else
        script = [.constant(1), .if, .zero, .if, .constant(1), .if, .constant(2), .endIf, .else, .constant(3), .endIf, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // 2 level nesting, alternate 1
        script = [.zero, .if, .constant(1), .if, .constant(1), .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([5])])

        // alternate 2
        script = [.constant(1), .if, .zero, .if, .constant(1), .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([4])])

        // alternate 2
        script = [.constant(1), .if, .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3), .endIf, .else, .constant(4), .endIf, .else, .constant(5), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])
    }

    @Test("Empty Branched")
    func emptyBranches() throws {
        // Empty if branch
        var script = BitcoinScript([.constant(1), .if, .else, .constant(3), .endIf])
        var stack = [Data]()
        try script.run(&stack)
        #expect(stack == [])

        // Empty if branch (negative)
        script = [.zero, .if, .else, .constant(3), .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([3])])

        // Empty else branch (activated)
        script = [.zero, .if, .constant(2), .else, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [])

        // Empty else branch (not activated)
        script = [.constant(1), .if, .constant(2), .else, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [Data([2])])

        // Empty branches
        script = [.constant(1), .if, .else, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [])

        // Empty branches (negative)
        script = [.zero, .if, .else, .endIf]
        stack = []
        try script.run(&stack)
        #expect(stack == [])
    }

    @Test("Minimal If")
    func minimalif() throws {
        // True-ish value
        var script = BitcoinScript([.constant(2), .if, .constant(2), .else, .constant(3), .endIf])
        var stack = [Data]()
        #expect(throws: (any Error).self) { try script.run(&stack, sigVersion: .witnessV0) }

        // Falsish value
        script = .init([.pushBytes(Data([0])), .if, .constant(2), .else, .constant(3), .endIf])
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack, sigVersion: .witnessV0) }

        // Falsish value not-if
        script = .init([.pushBytes(Data([0])), .notIf, .constant(2), .else, .constant(3), .endIf])
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack, sigVersion: .witnessV0) }

        // true-ish value not-if
        script = .init([.constant(2), .notIf, .constant(2), .else, .constant(3), .endIf])
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack, sigVersion: .witnessV0) }
    }

    @Test("VerIf")
    func verIf() throws {
        var script = BitcoinScript([.constant(1), .if, .verIf, .else, .constant(2), .endIf])
        var stack = [Data]()
        #expect(throws: (any Error).self) { try script.run(&stack) }

        script = [.constant(1), .if, .constant(2), .else, .verIf, .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        script = [.zero, .if, .verIf, .else, .constant(2), .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }
    }

    @Test("If + Op Success")
    func opSuccess() throws {
        var script = BitcoinScript([.constant(1), .if, .constant(2), .else, .success(80)])
        var stack = [Data]()
        try script.runV1(&stack)

        script = .init([.constant(1), .if, .success(80), .else, .constant(2), .endIf])
        stack = []
        try script.runV1(&stack)
    }

    @Test("Malformed If")
    func malformedIf() throws {
        // Missing endif
        var script = BitcoinScript([.constant(1), .if, .constant(1), .if, .constant(2), .endIf])
        var stack = [Data]()
        #expect(throws: (any Error).self) { try script.run(&stack) }

        // Too many endifs
        script = [.constant(1), .if, .constant(2), .endIf, .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        script = [.zero, .if, .constant(2), .endIf, .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        // Too many else's
        script = [.constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        // Too many else's (else branch evaluated)
        script = [.zero, .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        // interlaced
        script = [
            .constant(1), .if, .constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        script = [
            .zero, .if, .constant(1), .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }

        script = [
            .constant(1), .if, .zero, .if, .constant(2), .else, .constant(3), .else, .constant(4), .endIf, .endIf]
        stack = []
        #expect(throws: (any Error).self) { try script.run(&stack) }
    }
}
