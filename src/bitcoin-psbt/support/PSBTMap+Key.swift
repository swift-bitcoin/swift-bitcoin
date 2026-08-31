import Foundation
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

        init(from decoder: inout BinaryDecoder, format: Never?) throws(PSBTMapError) {
            do {
                let keySize = try VarInt(from: &decoder)
                let type = try VarInt(from: &decoder)
                let dataSize = keySize.value - type.binarySize
                self.type = type.value
                data = try decoder.decode(dataSize)
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

        func encode(into encoder: inout BinaryEncoder, format: Never?) {
            let type = VarInt(type)
            let keySize = VarInt(type.binarySize + data.count)
            encoder.encode(keySize)
            encoder.encode(type)
            encoder.encode(data)
        }
    }
}
