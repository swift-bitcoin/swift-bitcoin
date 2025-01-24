import Foundation
import BitcoinCrypto

/// Witness data associated with a particular ``TxIn``.
///
/// Refer to BIP141 for more information.
public struct TxWitness: Equatable, Sendable {

    public init(_ elements: [Data]) {
        self.elements = elements
    }

    /// The list of elements that makes up this witness.
    public let elements: [Data]

    /// BIP341
    var taprootAnnex: Data? {
        // If there are at least two witness elements, and the first byte of the last element is 0x50, this last element is called annex a
        if elements.count > 1, let maybeAnnex = elements.last, let firstElem = maybeAnnex.first, firstElem == 0x50 {
            return maybeAnnex
        } else {
            return .none
        }
    }
}

/// Binary data extensions.
extension TxWitness: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let count = (try decoder.take() as VarInt).value
        var elements = [Data]()
        for _ in 0 ..< count {
            let length = (try decoder.take() as VarInt).value
            elements.append(try decoder.take(length))
        }
        self.elements = elements
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.put(VarInt(elements.count))
        for e in elements {
            encoder.put(VarInt(e.count))
            encoder.put(e)
        }
    }

    public func reportSize(to visitor: inout BinarySizeVisitor) {
        visitor.count(VarInt(elements.count))
        for e in elements {
            visitor.count(VarInt(e.count))
            visitor.countSize(e.count)
        }
    }
}
