import Foundation
import BinaryParsing
import BitcoinCrypto

public enum TransportNetwork: Int {

    /// IPv4 address (globally routed internet)
    case IPV4 = 1

    /// IPv6 address (globally routed internet)
    case IPV6

    /// Tor v2 hidden service address
    case TorV2

    /// Tor v3 hidden service address
    case TorV3

    /// I2P overlay network address
    case I2P

    /// Cjdns overlay network address
    case CJDNS

    /// Address length in bytes.
    var addressLength: Int {
        switch self {
        case .IPV4:
            4
        case .IPV6:
            16
        case .TorV2:
            10
        case .TorV3:
            32
        case .I2P:
            32
        case .CJDNS:
            16
        }
    }
}

extension TransportNetwork: BinaryCodable {

    public enum ParseError: Error {
        /// Invalid network identifier value.
        case invalidNetworkIdentified(Int)
    }

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        let value = Int(try UInt8(parsing: &input))
        guard let network = TransportNetwork(rawValue: value) else {
            throw ParseError.invalidNetworkIdentified(value)
        }
        self = network
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt8.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt8(rawValue))
    }
}
