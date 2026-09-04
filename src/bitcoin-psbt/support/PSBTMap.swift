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

    init(parsing input: inout ParserSpan, format: Never?) throws(PSBTMapError) {
        var lookAhead = input.parserRange
        guard let maybeDelimiter = try? UInt8(parsing: &input) else {
            throw .missingDelimiter
        }
        do {
            try input.seek(toRange: lookAhead)
        } catch {
            throw .missingDelimiter
        }

        var entries = [Key : Data]()
        var foundDelimiter = maybeDelimiter == Self.delimiter
        while !foundDelimiter {
            let keypair: Keypair
            do {
                keypair = try Keypair(parsing: &input)
            } catch let error as PSBTMapError {
                throw error
            } catch {
                throw .invalidKeyPairEncoding
            }
            guard entries[keypair.key] == nil else {
                throw .duplicateKey
            }
            entries[keypair.key] = keypair.value

            lookAhead = input.parserRange
            guard let maybeDelimiter = try? UInt8(parsing: &input) else {
                throw .missingDelimiter
            }
            do {
                try input.seek(toRange: lookAhead)
            } catch {
                throw .missingDelimiter
            }

            foundDelimiter = maybeDelimiter == Self.delimiter
        }
        do {
            _ = try UInt8(parsing: &input) // Consume delimiter
        } catch {
            throw .missingDelimiter
        }
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
        counter.countSize(1) // delimiter
    }

    func encode(into out: inout OutputRawSpan, format: Never?) throws {
        for keypair in keypairs {
            try keypair.encode(into: &out)
        }
        out.append(Self.delimiter)
    }

    static let delimiter = UInt8(0x00)
}
