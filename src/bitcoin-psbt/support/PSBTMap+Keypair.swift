import Foundation
import BitcoinCrypto

extension PSBTMap {

    /// PSBT Keypair Structure
    ///
    /// Format:
    ///
    ///     <keypair> := <key> <value>
    ///     <key> := <keylen> <keytype> <keydata>
    ///     <value> := <valuelen> <valuedata>
    ///
    /// Where:
    ///
    /// `<keytype>` - A compact size unsigned integer representing the type. This compact size unsigned integer must be minimally encoded, i.e. if the value can be represented using one byte, it must be represented as one byte. There can be multiple entries with the same `<keytype>` within a specific `<map>`, but the `<key>` must be unique.
    /// `<keylen>` - The compact size unsigned integer containing the combined length of `<keytype>` and `<keydata>`
    /// `<valuelen>` - The compact size unsigned integer containing the length of `<valuedata>`.
    /// `<magic>` - Magic bytes which are ASCII for psbt [2] followed by a separator of `0xff`. This integer must be serialized in most significant byte order.
    ///
    struct Keypair: CustomBinaryCodable {

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }

        init(from decoder: inout BinaryDecoder, encoding: Never?) throws(PSBTMapError) {
            do {
                key = try decoder.decodeExplicit()
            } catch let error as PSBTMapError {
                throw error
            } catch {
                throw .invalidKeyEncoding
            }
            do {
                value = try decoder.decodeExplicit()
            } catch let error as PSBTMapError {
                throw error
            } catch {
                throw .invalidValueEncoding
            }
        }

        let key: Key
        let value: Value

        func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
            counter.count(key)
            counter.count(value)
        }

        func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
            encoder.encode(key)
            encoder.encode(value)
        }
    }
}
