import Foundation
import BinaryParsing
import BitcoinCrypto

extension Transaction {
    /// Witness data associated with a particular ``Transaction/Input``.
    ///
    /// Refer to BIP141 for more information.
    public struct Witness: Equatable, Sendable {

        public init(_ stack: [Data]) {
            self.stack = stack
        }

        /// The list of elements that makes up this witness.
        public var stack: [Data]

        /// BIP341
        var taprootAnnex: Data? {
            // If there are at least two witness elements, and the first byte of the last element is 0x50, this last element is called annex a
            if stack.count > 1, let maybeAnnex = stack.last, let firstElem = maybeAnnex.first, firstElem == Self.annexTag {
                return maybeAnnex
            } else {
                return nil
            }
        }

        /// The annex tag byte.
        ///
        /// Consumed externally by BitcoinBlockchain to check witness standardness.
        package static let annexTag = UInt8(0x50)

        /// The taproot leaf mask.
        ///
        /// Consumed externally by BitcoinBlockchain to check witness standardness.
        package static let taprootLeafMask: UInt8 = 0xfe

        /// The taproot leaf tapscript value.
        ///
        /// Consumed externally by BitcoinBlockchain to check witness standardness.
        package static let taprootLeafTapscript: UInt8 = 0xc0
    }
}

extension Transaction.Witness: ExpressibleByArrayLiteral {
    public init(arrayLiteral stack: Data...) {
        self.init(stack)
    }
}

/// Binary data extensions.
extension Transaction.Witness: BinaryCodable {
    public init(from decoder: inout BinaryDecoder, format: Never?) throws {
        let count = (try decoder.decode() as VarInt).value
        var stack = [Data]()
        for _ in 0 ..< count {
            stack.append(try decoder.decode(variable: true))
        }
        self.stack = stack
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(VarInt(stack.count))
        for e in stack {
            counter.count(e, variable: true)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try VarInt(stack.count).encode(into: &out)
        for e in stack {
            try VarInt(e.count).encode(into: &out)
            out.append(contentsOf: e)
        }
    }

    /*
    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(VarInt(stack.count))
        for e in stack {
            encoder.encode(e, variable: true)
        }
    }
    */
}
