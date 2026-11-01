import Foundation

// From swift-bitcoin, src/bitcoin-crypto/codec/Binary/OutputRawSpan+.swift (develop branch).
//
// Local changes from upstream:
// 1. `unsafe` markers wherever strict memory safety requires them. No behavior change.
// 2. Internal rather than public access, so these can't clash with a host project's own public
//    copies of the same extensions (two modules both adding a public `append(contentsOf:)` to
//    `OutputRawSpan` would make every call ambiguous in code that imports both).
// 3. A bug fix in `updateSubrange(_:copying:)`'s bounds check; see "Local change" below.

extension OutputRawSpan {

    /// Appends the raw bytes of a Data instance directly into the buffer layout.
    package mutating func append<D: ContiguousBytes>(contentsOf data: D) {
        unsafe data.withUnsafeBytes { sourceBuffer in
            guard unsafe !sourceBuffer.isEmpty else { return }

            // Gain access to the underlying storage pointer and the layout's active count
            unsafe withUnsafeMutableBytes { targetBuffer, initializedCount in

                // Precondition to protect against runtime buffer overflows
                precondition(targetBuffer.count - initializedCount >= sourceBuffer.count, "Out of bounds: OutputRawSpan has insufficient capacity.")

                // Point directly to the first uninitialized byte in the memory block
                //let destination = targetBuffer.baseAddress?.advanced(by: initializedCount)
                let writePointer = unsafe targetBuffer.baseAddress! + initializedCount

                // Access the source data's contiguous memory buffer safely
                unsafe data.withUnsafeBytes { sourceBuffer in
                    // Perform an optimized memcpy directly into the buffer layout
                    unsafe writePointer.copyMemory(from: sourceBuffer.baseAddress!, byteCount: sourceBuffer.count)
                }

                // Explicitly step the internal tracking counter forward
                initializedCount += sourceBuffer.count
            }
        }
    }
}

/// Polyfill until `MutableRawSpan.updateSubrange(:copying)` is approved and released in post Swift 6.4 versions.
///
/// See forum thread https://forums.swift.org/t/pitch-bulk-update-operations-for-mutablespan-and-mutablerawspan/89843
/// See proposal https://github.com/glessard/swift-evolution/blob/d389077c5d25f4828f4a068020ac4f87bb60aaa8/proposals/nnnn-mutablespan-bulk-updates.md#detailed-design
extension MutableRawSpan {
    package mutating func updateSubrange(
        _ subrange: Range<Int>,
        copying source: RawSpan
    ) {
        // 1. Trap on invalid programmer usage (Standard Library invariant)
        //
        // Local change (bug fix). Upstream checks:
        //
        //     self.byteOffsets.contains(subrange.lowerBound) &&
        //     (subrange.upperBound <= self.byteOffsets.upperBound)
        //
        // `byteOffsets` is the half-open range `0..<byteCount`, and a half-open range doesn't
        // contain its upper bound. So an empty subrange that starts at the end of the span, like
        // `8..<8` on an 8-byte span, fails `contains(8)` and traps. That also rules out `0..<0` on
        // an empty span, where `byteOffsets` is `0..<0` and contains nothing. Both are valid empty
        // ranges: step 2 below is meant to turn every empty range into a no-op, but upstream
        // reaches it only for empty ranges that start strictly inside the span. The standard
        // library accepts the end position in its own subrange APIs (`replaceSubrange`, slicing
        // with `count..<count`).
        //
        // The fix checks the same thing the second half of the upstream condition already did,
        // `upperBound <= byteCount`, plus a non-negative lower bound. A `Range` guarantees
        // `lowerBound <= upperBound`, so together these say the range fits inside
        // `0...byteCount`, which includes the end position. Non-empty ranges are accepted or
        // rejected exactly as before. Covered by `PolyfillTests` (`emptyRangeAtTheEndIsANoOp`,
        // `emptySpanAcceptsAnEmptyRange`, `trapsOutOfBounds`).
        precondition(
            subrange.lowerBound >= 0 && subrange.upperBound <= self.byteCount,
            "Subrange \(subrange) out of bounds for MutableRawSpan (bounds: \(self.byteOffsets))"
        )
        precondition(
            subrange.count == source.byteCount,
            "Byte count mismatch: subrange requires \(subrange.count) bytes, but source has \(source.byteCount)"
        )

        // 2. Legitimate zero-byte operation: No-op (like copyBytes/replaceSubrange)
        guard subrange.count > 0 else { return }

        // 3. Perform copy; baseAddress MUST NOT be nil if count > 0
        self.withUnsafeMutableBytes { destBuffer in
            source.withUnsafeBytes { srcBuffer in
                guard let destBase = destBuffer.baseAddress,
                      let srcBase = srcBuffer.baseAddress else {
                    preconditionFailure("Unexpected nil baseAddress in non-empty buffer")
                }

                unsafe destBase.advanced(by: subrange.lowerBound)
                    .copyMemory(from: srcBase, byteCount: source.byteCount)
            }
        }
    }
}
