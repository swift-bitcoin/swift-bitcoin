import Foundation
import BitcoinCrypto

extension PSBTMap {

    struct Value: Equatable, CustomBinaryCodable {

        init(data: Data) {
            self.data = data
        }

        init(from decoder: inout BinaryDecoder, encoding: Never?) throws(PSBTMapError) {
            do {
                data = try decoder.decode(variable: true)
            } catch {
                throw .invalidValueEncoding
            }
        }

        let data: Data

        func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
            counter.count(data, variable: true)
        }

        func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
            encoder.encode(data, variable: true)
        }
    }
}
