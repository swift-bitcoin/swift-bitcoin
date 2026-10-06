import Foundation

extension OutputRawSpan {

    /// Appends the raw bytes of a Data instance directly into the buffer layout.
    public mutating func append<D: ContiguousBytes>(contentsOf data: D) {
        data.withUnsafeBytes { sourceBuffer in
            guard !sourceBuffer.isEmpty else { return }

            // Gain access to the underlying storage pointer and the layout's active count
            withUnsafeMutableBytes { targetBuffer, initializedCount in

                // Precondition to protect against runtime buffer overflows
                precondition(targetBuffer.count - initializedCount >= sourceBuffer.count, "Out of bounds: OutputRawSpan has insufficient capacity.")

                // Point directly to the first uninitialized byte in the memory block
                //let destination = targetBuffer.baseAddress?.advanced(by: initializedCount)
                let writePointer = targetBuffer.baseAddress! + initializedCount

                // Access the source data's contiguous memory buffer safely
                data.withUnsafeBytes { sourceBuffer in
                    // Perform an optimized memcpy directly into the buffer layout
                    writePointer.copyMemory(from: sourceBuffer.baseAddress!, byteCount: sourceBuffer.count)
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
    public mutating func updateSubrange(
        _ subrange: Range<Int>,
        copying source: RawSpan
    ) {
        // 1. Trap on invalid programmer usage (Standard Library invariant)
        precondition(
            self.byteOffsets.contains(subrange.lowerBound) &&
            (subrange.upperBound <= self.byteOffsets.upperBound),
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

                destBase.advanced(by: subrange.lowerBound)
                    .copyMemory(from: srcBase, byteCount: source.byteCount)
            }
        }
    }
}
