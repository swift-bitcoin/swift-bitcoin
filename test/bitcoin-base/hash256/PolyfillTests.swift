import Foundation
import Testing

@testable import BitcoinCrypto

@Suite("Polyfills")
struct PolyfillTests {
    @Suite("OutputRawSpan.append(contentsOf:)")
    struct AppendContentsOf {
        @Test func appendsArraysAndData() {
            let wire = encoded(byteCount: 8) { output in
                output.append(contentsOf: [UInt8]([1, 2, 3]))
                output.append(contentsOf: Data([4, 5]))
                output.append(contentsOf: [UInt8]([6, 7, 8]))
                #expect(output.freeCapacity == 0)
            }
            #expect(wire == [1, 2, 3, 4, 5, 6, 7, 8])
        }

        @Test func emptyInputIsANoOp() {
            let wire = encoded(byteCount: 2) { output in
                output.append(contentsOf: [UInt8]())
                output.append(contentsOf: Data())
                #expect(output.byteCount == 0)
                output.append(contentsOf: [UInt8]([9]))
            }
            #expect(wire == [9])
        }

        /// Interleaves with the standard library's own appends.
        @Test func mixesWithTypedAppends() {
            let hash = randomHashes(1, seed: 80)[0]
            let wire = encoded(byteCount: 37) { output in
                output.append(contentsOf: [UInt8]([0xAA]))
                hash.encode(into: &output)
                output.append(UInt32(0x0102_0304), as: UInt32.self, .littleEndian)
            }
            #expect(wire == [0xAA] + bytes(of: hash) + [0x04, 0x03, 0x02, 0x01])
        }

        @Test func exactCapacityFits() {
            let payload = (0..<32).map(UInt8.init)
            #expect(encoded(byteCount: 32) { $0.append(contentsOf: payload) } == payload)
        }

        @Test func trapsWithoutRoom() async {
            await #expect(processExitsWith: .failure) {
                withTemporaryAllocation(byteCount: 3, alignment: 1) { output in
                    output.append(contentsOf: [UInt8]([1, 2, 3, 4]))
                }
            }
        }
    }

    @Suite("MutableRawSpan.updateSubrange(_:copying:)")
    struct UpdateSubrange {
        /// Applies `updateSubrange` to an 8-byte buffer of 0xFF and returns the result.
        private func updating(_ range: Range<Int>, with source: [UInt8]) -> [UInt8] {
            var buffer = [UInt8](repeating: 0xFF, count: 8)
            var span = buffer.mutableSpan
            var raw = span.mutableBytes
            raw.updateSubrange(range, copying: source.span.bytes)
            return buffer
        }

        @Test func copiesIntoTheMiddle() {
            #expect(updating(2..<5, with: [1, 2, 3]) == [0xFF, 0xFF, 1, 2, 3, 0xFF, 0xFF, 0xFF])
        }

        @Test func copiesAtBothEnds() {
            #expect(updating(0..<2, with: [7, 8]) == [7, 8] + [UInt8](repeating: 0xFF, count: 6))
            #expect(updating(6..<8, with: [7, 8]) == [UInt8](repeating: 0xFF, count: 6) + [7, 8])
            #expect(updating(0..<8, with: Array(0..<8)) == Array(0..<8))
        }

        @Test func emptyRangeIsANoOp() {
            #expect(updating(3..<3, with: []) == [UInt8](repeating: 0xFF, count: 8))
        }

        /// Upstream traps here: `byteOffsets.contains(8)` is false for an 8-byte span.
        @Test func emptyRangeAtTheEndIsANoOp() {
            #expect(updating(0..<0, with: []) == [UInt8](repeating: 0xFF, count: 8))
            #expect(updating(8..<8, with: []) == [UInt8](repeating: 0xFF, count: 8))
        }

        @Test func emptySpanAcceptsAnEmptyRange() {
            var buffer = [UInt8]()
            var span = buffer.mutableSpan
            var raw = span.mutableBytes
            let empty: [UInt8] = []
            raw.updateSubrange(0..<0, copying: empty.span.bytes)
            #expect(buffer.isEmpty)
        }

        @Test func trapsOnLengthMismatch() async {
            await #expect(processExitsWith: .failure) {
                var buffer = [UInt8](repeating: 0, count: 8)
                var span = buffer.mutableSpan
                var raw = span.mutableBytes
                let source: [UInt8] = [1, 2]
                raw.updateSubrange(0..<3, copying: source.span.bytes)
            }
        }

        @Test func trapsOutOfBounds() async {
            await #expect(processExitsWith: .failure) {
                var buffer = [UInt8](repeating: 0, count: 8)
                var span = buffer.mutableSpan
                var raw = span.mutableBytes
                let source: [UInt8] = [1, 2]
                raw.updateSubrange(7..<9, copying: source.span.bytes)
            }
        }
    }

    @Suite("Data(capacity:initializingWith:)")
    struct DataCapacity {
        private struct Failure: Error, Equatable {}

        @Test func takesTheWrittenBytes() {
            let data = Data(capacity: 6) { output in
                output.append(UInt32(0x0102_0304), as: UInt32.self, .bigEndian)
                output.append(contentsOf: [UInt8]([5, 6]))
            }
            #expect(data == Data([1, 2, 3, 4, 5, 6]))
        }

        @Test func zeroCapacityIsEmpty() {
            #expect(Data(capacity: 0) { _ in }.isEmpty)
        }

        @Test func rethrowsTheClosuresError() {
            #expect(throws: Failure()) {
                _ = try Data(capacity: 8) { (output: inout OutputRawSpan) throws(Failure) in
                    output.append(contentsOf: [UInt8]([1, 2, 3]))
                    throw Failure()
                }
            }
        }

        @Test func trapsWhenUnderWritten() async {
            await #expect(processExitsWith: .failure) {
                _ = Data(capacity: 4) { $0.append(contentsOf: [UInt8]([1, 2])) }
            }
        }

        @Test func trapsWhenOverWritten() async {
            await #expect(processExitsWith: .failure) {
                _ = Data(capacity: 2) { $0.append(contentsOf: [UInt8]([1, 2, 3])) }
            }
        }

        @Test func trapsOnNegativeCapacity() async {
            await #expect(processExitsWith: .failure) {
                _ = Data(capacity: -1) { _ in }
            }
        }
    }

    @Suite("Data and [UInt8] from spans")
    struct CopyingInitializers {
        @Test(arguments: [0, 1, 32, 1_000])
        func copyRawSpans(count: Int) {
            let source = (0..<count).map { UInt8(truncatingIfNeeded: $0) }
            let data = Data(source.span.bytes)
            let array = [UInt8](source.span.bytes)
            #expect(data == Data(source))
            #expect(array == source)
        }

        @Test func copiesASlice() {
            let source = Array(0..<10).map(UInt8.init)
            let array = [UInt8](source.span.bytes.extracting(3..<7))
            #expect(array == [3, 4, 5, 6])
        }

        @Test func copiesWhatAnOutputRawSpanHolds() {
            let data = withTemporaryAllocation(byteCount: 8, alignment: 1) { output in
                output.append(contentsOf: [UInt8]([9, 8, 7]))
                return Data(output)
            }
            #expect(data == Data([9, 8, 7]))
        }
    }
}
