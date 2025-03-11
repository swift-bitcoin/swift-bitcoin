import Foundation
import BitcoinCrypto

struct BlockStorageLocator: Hashable {
    let file: Int
    let offset: Int
}

extension BlockStorageLocator: BinaryCodable {
    init(from decoder: inout BinaryDecoder) throws {
        file = try decoder.decode()
        offset = try decoder.decode()
    }

    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(file)
        encoder.encode(offset)
    }

    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(Int.self)
        counter.count(Int.self)
    }
}
