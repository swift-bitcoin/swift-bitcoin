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
    struct Keypair: BinaryCodable {

        init(key: Key, value: Data) {
            self.key = key
            self.value = value
        }

        init(from decoder: inout BinaryDecoder, format: Never?) throws(PSBTMapError) {
            do {
                key = try decoder.decodeExplicit()
            } catch let error as PSBTMapError {
                throw error
            } catch {
                throw .invalidKeyEncoding
            }
            do {
                value = try decoder.decode(variable: true)
            } catch let error as PSBTMapError {
                throw error
            } catch {
                throw .invalidValueEncoding
            }
        }

        let key: Key
        let value: Data

        func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
            counter.count(key)
            counter.count(value, variable: true)
        }

        func encode(into encoder: inout BinaryEncoder, format: Never?) {
            encoder.encode(key)
            encoder.encode(value, variable: true)
        }
    }
}
