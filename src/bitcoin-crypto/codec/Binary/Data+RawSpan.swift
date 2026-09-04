import Foundation

// MARK: - Polyfill: Data(exactRawSize:building:)

extension Data {
    /// Allocates exactly `size` bytes, lets `initializer` append into them, then
    /// transfers ownership of the allocation to `Data` — no copy, no memset.
    ///
    /// Traps if the closure writes fewer than `size` bytes. Writing *more* is
    /// already caught inside `OutputRawSpan.append` when capacity runs out, so
    /// between the two there is no way to hand back uninitialized garbage.
    public init<E: Error>(
        capacity size: Int,
        initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) {
        precondition(size >= 0, "size must be non-negative")
        guard size > 0 else { self = Data(); return }

        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 1)
        var out = OutputRawSpan(buffer: raw, initializedCount: 0)

        do {
            try initializer(&out)
        } catch {
            // The closure throwing must not leak the allocation.
            _ = out.finalize(for: raw)
            raw.deallocate()
            throw error
        }

        let written = out.finalize(for: raw)
        precondition(written == size, "declared \(size) bytes but wrote \(written)")

        self = Data(
            bytesNoCopy: raw.baseAddress!,
            count: written,
            deallocator: .custom { pointer, _ in pointer.deallocate() }
        )
    }
}

extension Data {

    /// Creates data from a raw span.
    /// - Parameter span: The raw span whose bytes to copy into a new Data.
    public init(_ span: RawSpan) {
        self = span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return Data()
            }
            return Data(bytes: base, count: pointer.count)
        }
    }

    public init(_ span: borrowing OutputRawSpan) {
        self = span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return Data()
            }
            return Data(bytes: base, count: pointer.count)
        }
    }
}

extension Array where Element == UInt8 {
    public init(_ span: RawSpan) {
        self = span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return []
            }
            return Array(UnsafeBufferPointer<UInt8>(start: base.assumingMemoryBound(to: UInt8.self), count: pointer.count))
        }
    }
}
