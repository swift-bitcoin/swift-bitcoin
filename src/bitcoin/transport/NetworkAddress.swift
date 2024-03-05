import Foundation

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

extension NetworkAddress {

    public init?(_ data: Data) {
        guard data.count >= Self.baseSize else { return nil }
        var data = data

        guard data.count >= MemoryLayout<UInt32>.size else { return nil }
        let time = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        self.time = Date(timeIntervalSince1970: TimeInterval(time))
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        guard let servicesValue = data.varInt else { return nil }
        self.services = ProtocolServices(rawValue: servicesValue)
        data = data.dropFirst(servicesValue.varIntSize)

        guard let networkID = TransportNetwork(data) else { return nil }
        self.networkID = networkID
        data = data.dropFirst(TransportNetwork.size)

        guard data.count >= networkID.addressLength else { return nil }
        addressData = Data(data[..<data.startIndex.advanced(by: networkID.addressLength)])
        data = data.dropFirst(networkID.addressLength)

        guard data.count >= MemoryLayout<UInt16>.size else { return nil }
        let port = data.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
        self.port = Int(port)
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addBytes(UInt32(time.timeIntervalSince1970))
        offset = ret.addData(Data(varInt: services.rawValue), at: offset)
        offset = ret.addData(networkID.data)
        offset = ret.addData(addressData)
        ret.addBytes(UInt16(port))
        return ret
    }

    var size: Int {
        Self.baseSize +
            services.rawValue.varIntSize +
            networkID.addressLength
    }

    static var baseSize: Int {
        MemoryLayout<UInt32>.size +
            TransportNetwork.size +
            MemoryLayout<UInt16>.size
    }
}
