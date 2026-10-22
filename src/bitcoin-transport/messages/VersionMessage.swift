import Foundation
import BinaryParsing
import BitcoinCrypto

struct VersionMessage: Equatable, Sendable {
    init(protocolVersion: ProtocolVersion = .latest, services: ProtocolServices = .all, receiverServices: ProtocolServices? = nil, receiverAddress: IPv6Address? = nil, receiverPort: Int? = nil, transmitterAddress: IPv6Address? = nil, transmitterPort: Int? = nil, nonce: UInt64 = 0, userAgent: String = "/SwiftBitcoin:0.1.0/", startHeight: Int = 0, relay: Bool = true) {
        self.protocolVersion = protocolVersion
        self.services = services
        self.timestamp = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.down))
        self.receiverServices = receiverServices ?? .empty
        self.receiverAddress = receiverAddress ?? .unspecified
        self.receiverPort = receiverPort ?? 0
        self.transmitterServices = services
        self.transmitterAddress = transmitterAddress ?? .unspecified
        self.transmitterPort = transmitterPort ?? 0
        self.nonce = nonce
        self.userAgent = userAgent
        self.startHeight = startHeight
        self.relay = relay
    }

    let protocolVersion: ProtocolVersion
    let services: ProtocolServices
    let timestamp: Date
    let receiverServices: ProtocolServices
    let receiverAddress: IPv6Address
    let receiverPort: Int
    let transmitterServices: ProtocolServices
    let transmitterAddress: IPv6Address
    let transmitterPort: Int
    let nonce: UInt64
    let userAgent: String
    let startHeight: Int
    let relay: Bool

    var userAgentData: Data {
        userAgent.data(using: .ascii)!
    }
}

extension VersionMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        protocolVersion = try ProtocolVersion(parsing: &input)
        services = try ProtocolServices(parsing: &input)
        timestamp = Date(timeIntervalSince1970: TimeInterval(try Int64(parsingLittleEndian: &input)))
        receiverServices = try ProtocolServices(parsing: &input)
        receiverAddress = IPv6Address(try Data([UInt8](parsing: &input, byteCount: IPv6Address.size)))
        receiverPort = Int(try UInt16(parsingBigEndian: &input))
        transmitterServices = try ProtocolServices(parsing: &input)
        transmitterAddress = IPv6Address(try Data([UInt8](parsing: &input, byteCount: IPv6Address.size)))
        transmitterPort = Int(try UInt16(parsingBigEndian: &input))
        nonce = try UInt64(parsingLittleEndian: &input)
        let userAgentDataCount = try VarInt(parsing: &input).value
        let userAgentData = try Data([UInt8](parsing: &input, byteCount: userAgentDataCount))
        userAgent = String(decoding: userAgentData, as: Unicode.ASCII.self)
        startHeight = Int(try Int32(parsingLittleEndian: &input))
        relay = try UInt8(parsing: &input) != 0 ? true : false
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        protocolVersion.countBytes(into: &counter)
        counter.count(services)
        counter.count(Int64.self)
        counter.count(receiverServices)
        counter.countSize(IPv6Address.size)
        counter.count(UInt16.self)
        counter.count(transmitterServices)
        counter.countSize(IPv6Address.size)
        counter.count(UInt16.self)
        counter.count(UInt64.self)
        counter.count(VarInt(userAgentData.count))
        counter.countSize(userAgentData.count)
        counter.count(Int32.self)
        counter.count(UInt8.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try protocolVersion.encode(into: &out)
        try services.encode(into: &out)
        out.append(Int64(timestamp.timeIntervalSince1970), as: Int64.self, .littleEndian)
        try receiverServices.encode(into: &out)
        out.append(contentsOf: receiverAddress.rawValue)
        out.append(UInt16(receiverPort), as: UInt16.self, .bigEndian)
        try transmitterServices.encode(into: &out)
        out.append(contentsOf: transmitterAddress.rawValue)
        out.append(UInt16(transmitterPort), as: UInt16.self, .bigEndian)
        out.append(nonce, as: UInt64.self, .littleEndian)
        try VarInt(userAgentData.count).encode(into: &out)
        out.append(contentsOf: userAgentData)
        out.append(Int32(startHeight), as: Int32.self, .littleEndian)
        out.append(UInt8(relay ? 1 : 0))
    }
}
