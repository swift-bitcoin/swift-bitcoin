import Foundation
import BinaryParsing
import BitcoinCrypto

/// BIP155
public struct AddrV2Message: Equatable {

    public init(addresses: [NetworkAddress]) {
        self.addresses = addresses
    }

    public let addresses: [NetworkAddress]
}

extension AddrV2Message: BinaryCodable {

    public enum ParseError: Error {
        /// Maximum address count is 1000.
        case tooManyAddresses
    }

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        // BIP155: One message can contain up to 1,000 addresses. Clients SHOULD reject messages with more addresses.
        let addressesCount = try VarInt(parsing: &input).value
        guard addressesCount <= 1_000 else {
            throw ParsingError(userError: ParseError.tooManyAddresses)
        }
        var addresses = [NetworkAddress]()
        for _ in 0 ..< addressesCount {
            let address = try NetworkAddress(parsing: &input)
            addresses.append(address)
        }
        self.addresses = addresses
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(VarInt(addresses.count))
        for address in addresses {
            counter.count(address)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try VarInt(addresses.count).encode(into: &out)
        for address in addresses {
            try address.encode(into: &out)
        }
    }
}
