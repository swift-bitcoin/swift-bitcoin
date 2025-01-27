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

extension TxWitness: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Data...) {
        self.init(elements)
    }
}

/// Binary data extensions.
extension TxWitness: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let count = (try decoder.decode() as VarInt).value
        var elements = [Data]()
        for _ in 0 ..< count {
            elements.append(try decoder.decode(variable: true))
        }
        self.elements = elements
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(VarInt(elements.count))
        for e in elements {
            encoder.encode(e, variable: true)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(VarInt(elements.count))
        for e in elements {
            counter.count(e, variable: true)
        }
    }
}
