import Foundation
import BinaryParsing
import BitcoinCrypto

public struct NetworkAddress: Equatable {

    public init(time: Date, services: ProtocolServices, networkID: TransportNetwork, addressData: Data, port: Int) {
        self.time = time
        self.services = services
        self.networkID = networkID
        self.addressData = addressData
        self.port = port
    }

    public let time: Date
    public let services: ProtocolServices
    public let networkID: TransportNetwork
    public let addressData: Data
    public let port: Int
}

extension NetworkAddress: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        time = Date(timeIntervalSince1970: TimeInterval(try Int64(parsingLittleEndian: &input)))
        services = ProtocolServices(rawValue: try VarInt(parsing: &input).rawValue)
        networkID = try TransportNetwork(parsing: &input)
        addressData = try Data([UInt8](parsing: &input, byteCount: networkID.addressLength))
        port = Int(try UInt16(parsingLittleEndian: &input))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
        counter.count(VarInt(rawValue: services.rawValue))
        counter.count(networkID)
        counter.countSize(networkID.addressLength)
        counter.count(UInt16.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt32(time.timeIntervalSince1970), as: UInt32.self, .littleEndian)
        try VarInt(rawValue: services.rawValue).encode(into: &out)
        try networkID.encode(into: &out)
        out.append(contentsOf: addressData)
        out.append(UInt16(port), as: UInt16.self, .littleEndian)
    }
}
