import Foundation
import BinaryParsing
import BitcoinCrypto

public enum PSBTMapError: Error {
    case /*invalidKeyType, invalidKeyData,*/ invalidKeyEncoding, invalidValueEncoding, invalidKeyPairEncoding, duplicateKey, missingDelimiter
}

struct PSBTMap: BinaryCodable {

    init(entries: [Key : Data]) {
        self.entries = entries
    }

    init(from decoder: inout BinaryDecoder, format: Never?) throws(PSBTMapError) {
        guard let maybeDelimiter = decoder.peek() else {
            throw .missingDelimiter
        }
        var entries = [Key : Data]()
        var foundDelimiter = maybeDelimiter == Self.delimiter
        while !foundDelimiter {
            let keypair: Keypair
            do {
                keypair = try decoder.decode()
            } catch let error as PSBTMapError {
                throw error
            } catch {
                throw .invalidKeyPairEncoding
            }
            guard entries[keypair.key] == nil else {
                throw .duplicateKey
            }
            entries[keypair.key] = keypair.value
            guard let maybeDelimiter = decoder.peek() else {
                throw .missingDelimiter
            }
            foundDelimiter = maybeDelimiter == Self.delimiter
        }
        _ = try! decoder.decode() as UInt8 // Consume delimiter
        self.entries = entries
    }

    let entries: [Key : Data]

    private var keypairs: [Keypair] {
        entries.map { Keypair(key: $0, value: $1) }
    }

    func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        for keypair in keypairs {
            counter.count(keypair)
        }
        counter.count(Self.delimiter)
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        for keypair in keypairs {
            try keypair.encode(into: &out)
        }
        out.append(Self.delimiter)
    }

    /*
    func encode(into encoder: inout BinaryEncoder, format: Never?) {
        for keypair in keypairs {
            encoder.encode(keypair)
        }
        encoder.encode(Self.delimiter)
    }
    */

    static let delimiter = UInt8(0x00)
}
