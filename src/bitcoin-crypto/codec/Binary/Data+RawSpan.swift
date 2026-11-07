import Foundation

// From swift-bitcoin, src/bitcoin-crypto/codec/Binary/Data+RawSpan.swift (develop branch).
//
// Local changes from upstream:
// 1. `unsafe` markers wherever strict memory safety requires them. No behavior change.
// 2. Package rather than public access, so these can't clash with a host project's own package
//    copies of the same extensions.
// 3. A memory-model fix in `[UInt8](_: RawSpan)`; see "Local change" below.

// MARK: - Polyfill: Data(exactRawSize:building:)

extension Data {
    /// Allocates exactly `size` bytes, lets `initializer` append into them, then
    /// transfers ownership of the allocation to `Data` — no copy, no memset.
    ///
    /// Traps if the closure writes fewer than `size` bytes. Writing *more* is
    /// already caught inside `OutputRawSpan.append` when capacity runs out, so
    /// between the two there is no way to hand back uninitialized garbage.
    package init<E: Error>(
        capacity size: Int,
        initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) {
        precondition(size >= 0, "size must be non-negative")
        guard size > 0 else {
            self = Data()
            return
        }

        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 1)
        var out = unsafe OutputRawSpan(buffer: raw, initializedCount: 0)

        do {
            try initializer(&out)
        } catch {
            // The closure throwing must not leak the allocation.
            _ = unsafe out.finalize(for: raw)
            unsafe raw.deallocate()
            throw error
        }

        let written = unsafe out.finalize(for: raw)
        precondition(written == size, "declared \(size) bytes but wrote \(written)")

        self = unsafe Data(
            bytesNoCopy: raw.baseAddress!,
            count: written,
            deallocator: .custom { pointer, _ in unsafe pointer.deallocate() }
        )
    }
}

extension Data {
    /// Creates data from a raw span.
    /// - Parameter span: The raw span whose bytes to copy into a new Data.
    package init(_ span: RawSpan) {
        self = span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return Data()
            }
            return unsafe Data(bytes: base, count: pointer.count)
        }
    }

    package init(_ span: borrowing OutputRawSpan) {
        self = unsafe span.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else {
                return Data()
            }
            return unsafe Data(bytes: base, count: pointer.count)
        }
    }
}

extension Array where Element == UInt8 {
    package init(_ span: RawSpan) {
        // Local change (memory-model fix). Upstream builds the array like this:
        //
        //     guard let base = pointer.baseAddress else { return [] }
        //     return Array(UnsafeBufferPointer<UInt8>(
        //         start: base.assumingMemoryBound(to: UInt8.self), count: pointer.count))
        //
        // `assumingMemoryBound(to:)` asserts that the memory is already bound to `UInt8` and
        // turns the raw pointer into a typed one. It doesn't check that assertion, and the bytes
        // a `RawSpan` covers can be bound to some other type: a span over an
        // `InlineArray<32, UInt8>` happens to be bound to `UInt8`, but one over a `UInt128`, a
        // tuple, or a struct isn't. Reading memory bound to one type through a typed pointer of
        // another is undefined behavior in Swift's memory model, even when the bit patterns are
        // what you expect. It works today, but the compiler is allowed to assume it never
        // happens, so an optimization could miscompile it later.
        //
        // The fix needs no typed pointer. `UnsafeRawBufferPointer` is already a `Collection`
        // whose elements are `UInt8`, read with raw loads, which are valid for memory bound to
        // any type. `Array(pointer)` copies those bytes directly. It also makes the `baseAddress`
        // guard unnecessary: an empty buffer has a nil `baseAddress` and simply produces an empty
        // array. The result is byte-for-byte the same. Covered by `PolyfillTests` (`copyRawSpans`
        // with 0, 1, 32 and 1,000 bytes, and `copiesASlice`).
        self = span.withUnsafeBytes { pointer in unsafe Array(pointer) }
    }
}
