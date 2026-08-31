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
