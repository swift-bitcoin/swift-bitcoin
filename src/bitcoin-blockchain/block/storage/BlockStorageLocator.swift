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
    init(from decoder: inout BinaryDecoder, format: Never?) throws {
        file = try decoder.decode()
        offset = try decoder.decode()
        undoOffset = try decoder.decode()
    }

    func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(Int.self)
        counter.count(Int.self)
        counter.count(Int.self)
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(file, as: Int.self, .littleEndian)
        out.append(offset, as: Int.self, .littleEndian)
        out.append(undoOffset, as: Int.self, .littleEndian)
    }

    /*
    func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(file)
        encoder.encode(offset)
        encoder.encode(undoOffset)
    }
    */
}
