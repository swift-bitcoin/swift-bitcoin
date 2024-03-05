import Foundation

/// BIP155
public struct AddrV2Message: Equatable {

    public init(addresses: [NetworkAddress]) {
        self.addresses = addresses
    }

    public let addresses: [NetworkAddress]
}

extension AddrV2Message {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        // BIP155: One message can contain up to 1,000 addresses. Clients SHOULD reject messages with more addresses.
        guard let addressesCount = data.varInt, addressesCount <= 1_000 else { return nil }
        var addresses = [NetworkAddress]()
        for _ in 0 ..< addressesCount {
            guard let address = NetworkAddress(data) else { return nil }
            addresses.append(address)
        }
        self.addresses = addresses
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(Data(varInt: UInt64(addresses.count)))
        for address in addresses {
            offset = ret.addData(address.data, at: offset)
        }
        return ret
    }

    var size: Int {
        UInt64(addresses.count).varIntSize + addresses.reduce(0) { $0 + $1.size }
    }
}
