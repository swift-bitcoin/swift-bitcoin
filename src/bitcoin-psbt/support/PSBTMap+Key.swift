import Foundation
import BinaryParsing
import BitcoinCrypto

extension PSBTMap {

    struct Key: Equatable, Hashable, BinaryCodable {

        init<K: KeyType>(_ type: K, data: Data = .init()) where K.RawValue == Int {
            self.type = type.rawValue
            self.data = data
        }

        init(type: Int, data: Data) {
            self.type = type
            self.data = data
        }

        init(parsing input: inout ParserSpan, format: Never?)  throws(PSBTMapError) {
            do {
                let keySize = try VarInt(parsing: &input)
                let type = try VarInt(parsing: &input)
                let dataSize = keySize.value - type.binarySize
                self.type = type.value
                data = try Data(parsing: &input, byteCount: dataSize)
            } catch {
                throw .invalidKeyEncoding
            }
        }

        let type: Int
        let data: Data

        func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
            let type = VarInt(type)
            let keySize = VarInt(type.binarySize + data.count)
            counter.count(keySize)
            counter.count(type)
            counter.count(data)
        }

        func encode(into out: inout OutputRawSpan, format: Never?) throws {
            let type = VarInt(type)
            let keySize = VarInt(type.binarySize + data.count)
            try keySize.encode(into: &out)
            try type.encode(into: &out)
            out.append(contentsOf: data)
        }
    }
}
