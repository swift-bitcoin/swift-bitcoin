import Foundation
import BitcoinCrypto

struct BlockStorageLocator: Hashable {
    let file: Int
    let offset: Int
    let undoOffset: Int

    static let placeholder = Self(file: -1, offset: -1, undoOffset: -1)

    var isComplete: Bool {
        offset != -1 && undoOffset != -1
    }

    var isPlaceholder: Bool {
        self == Self.placeholder
    }

    var hasUndoOffset: Bool {
        undoOffset != -1
    }
}

extension BlockStorageLocator: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws {
        file = try decoder.decode()
        offset = try decoder.decode()
        undoOffset = try decoder.decode()
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(file)
        encoder.encode(offset)
        encoder.encode(undoOffset)
    }

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(Int.self)
        counter.count(Int.self)
        counter.count(Int.self)
    }
}
