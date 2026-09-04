import Foundation
import BinaryParsing
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
        undoOffset != -1 // TODO: Change -1 for UInt32.max as fixed value
    }
}

extension BlockStorageLocator: BinaryCodable {

    init(parsing input: inout ParserSpan, format: Never?) throws {
        let file32 = try UInt32(parsingLittleEndian: &input)
        file = file32 == .max ? -1 : Int(file32)
        let offset32 = try UInt32(parsingLittleEndian: &input)
        offset = offset32 == .max ? -1 : Int(offset32)
        let undoOffset32 = try UInt32(parsingLittleEndian: &input)
        undoOffset = undoOffset32 == .max ? -1 : Int(undoOffset32)
    }

    func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
        counter.count(UInt32.self)
        counter.count(UInt32.self)
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(file == -1 ? .max : UInt32(file), as: UInt32.self, .littleEndian)
        out.append(offset == -1 ? .max : UInt32(offset), as: UInt32.self, .littleEndian)
        out.append(undoOffset == -1 ? .max : UInt32(undoOffset), as: UInt32.self, .littleEndian)
    }
}
