import Foundation

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

extension TransportNetwork {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let value = data.withUnsafeBytes { $0.loadUnaligned(as: UInt8.self) }
        self.init(rawValue: Int(value))
    }

    var data: Data {
        Data(value: UInt8(rawValue))
    }

    static var size: Int { MemoryLayout<UInt8>.size }
}
